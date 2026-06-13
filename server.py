import os
import subprocess
import base64
import io
import json
import socket
import threading
import sys
import time
import platform
import pyautogui
import qrcode
from PIL import Image, ImageDraw
import pystray
import webbrowser
from flask import Flask, render_template, request, send_from_directory, jsonify, send_file
from flask_socketio import SocketIO, emit
from zeroconf import ServiceInfo, Zeroconf

from modules.system import get_pc_stats
from modules.stream import start_stream, stop_stream, stream_loop, set_monitor
from modules.clipboard import start_clipboard_sync, set_clipboard
from modules.files import get_files_list, save_uploaded_file
from modules.media import start_media_sync, media_action
from modules.notifications import start_notifications_sync
from modules.macros import play_macro
from modules.schedule_actions import schedule_action, get_scheduled_jobs
from modules.presentation import start_presentation_overlay, move_laser, hide_laser
from modules.security import check_rate_limit, record_failed_attempt, reset_attempts, generate_token, is_valid_token
from modules.windows import get_windows, window_action

# Configuration
CONFIG_FILE = 'config.json'

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
        except Exception:
            pass
    return {'pin': '1234'}

def save_config(config):
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f)

config = load_config()
PIN = config.get('pin', '1234')

# Network
def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # doesn't even have to be reachable
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

local_ip = get_local_ip()
server_url = f"http://{local_ip}:5000"
system_os = platform.system()

# Flask Setup
app = Flask(__name__)
app.config['SECRET_KEY'] = 'mac-remote-secret!'
socketio = SocketIO(app, cors_allowed_origins="*")
authenticated_sids = set()

def stats_loop():
    while True:
        try:
            time.sleep(2)
            if authenticated_sids:
                stats = get_pc_stats()
                socketio.emit('pc_stats', stats)
        except Exception as e:
            print("Stats error:", e)

threading.Thread(target=stats_loop, daemon=True).start()
start_clipboard_sync(socketio, authenticated_sids)
start_media_sync(socketio, authenticated_sids)
start_notifications_sync(socketio, authenticated_sids)
start_presentation_overlay()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/manifest.json')
def manifest():
    manifest_data = {
        "name": "Remote Control",
        "short_name": "Remote",
        "start_url": "/",
        "display": "standalone",
        "background_color": "#f4f8fc",
        "theme_color": "#276ef1",
        "icons": [
            {
                "src": "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMjc2ZWYxIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHJlY3QgeD0iMiIgeT0iNCIgd2lkdGg9IjIwIiBoZWlnaHQ9IjE2IiByeD0iMiIgcnk9IjIiPjwvcmVjdD48bGluZSB4MT0iNiIgeTE9IjgiIHgyPSI2IiB5Mj0iOCI+PC9saW5lPjxsaW5lIHgxPSIxMCIgeTE9IjgiIHgyPSIxMCIgeTI9IjgiPjwvbGluZT48bGluZSB4MT0iMTQiIHkxPSI4IiB4Mj0iMTQiIHkyPSI4Ij48L2xpbmU+PGxpbmUgeDE9IjE4IiB5MT0iOCIgeDI9IjE4IiB5Mj0iOCI+PC9saW5lPjxsaW5lIHgxPSI2IiB5MT0iMTIiIHgyPSI2IiB5Mj0iMTIiPjwvbGluZT48bGluZSB4MT0iMTAiIHkxPSIxMiIgeDI9IjEwIiB5Mj0iMTIiPjwvbGluZT48bGluZSB4MT0iMTQiIHkxPSIxMiIgeDI9IjE0IiB5Mj0iMTIiPjwvbGluZT48bGluZSB4MT0iMTgiIHkxPSIxMiIgeDI9IjE4IiB5Mj0iMTIiPjwvbGluZT48bGluZSB4MT0iOCIgeTE9IjE2IiB4Mj0iMTYiIHkyPSIxNiI+PC9saW5lPjwvc3ZnPg==",
                "sizes": "192x192",
                "type": "image/svg+xml"
            }
        ]
    }
    return manifest_data

@app.route('/files', methods=['GET'])
def get_files():
    path = request.args.get('path')
    return jsonify(get_files_list(path))

@app.route('/download', methods=['GET'])
def download_file():
    path = request.args.get('path')
    if path and os.path.exists(path) and not os.path.isdir(path):
        return send_file(path, as_attachment=True)
    return "File not found", 404

@socketio.on('connect')
def test_connect():
    pass

@socketio.on('disconnect')
def test_disconnect():
    if request.sid in authenticated_sids:
        authenticated_sids.remove(request.sid)
    stop_stream()

@socketio.on('authenticate')
def handle_authenticate(data):
    ip = request.remote_addr
    if not check_rate_limit(ip):
        emit('authenticated', {'status': 'fail', 'message': 'Too many failed attempts. Locked out for 5 minutes.'})
        return

    pin = data.get('pin')
    token = data.get('token')
    config_pin = load_config().get('pin')
    
    if token and is_valid_token(token):
        authenticated_sids.add(request.sid)
        emit('authenticated', {'status': 'success', 'token': token})
        reset_attempts(ip)
    elif pin == config_pin:
        authenticated_sids.add(request.sid)
        new_token = generate_token()
        emit('authenticated', {'status': 'success', 'token': new_token})
        reset_attempts(ip)
    else:
        record_failed_attempt(ip)
        emit('authenticated', {'status': 'fail', 'message': 'Invalid PIN.'})

def is_authenticated():
    return request.sid in authenticated_sids

@socketio.on('upload_file')
def handle_upload(data):
    if not is_authenticated():
        return
    filename = data.get('filename')
    file_data_b64 = data.get('base64data')
    if filename and file_data_b64:
        try:
            file_data = base64.b64decode(file_data_b64)
            save_uploaded_file(filename, file_data)
            emit('upload_success', {'filename': filename})
        except Exception as e:
            emit('error', {'message': str(e)})

@socketio.on('set_clipboard')
def handle_set_clipboard(data):
    if not is_authenticated():
        return
    text = data.get('text')
    if text:
        set_clipboard(text)

@socketio.on('command')
def handle_command(data):
    if not is_authenticated():
        emit('error', {'message': 'Not authenticated'})
        return
        
    cmd_type = data.get('type')
    action = data.get('action')
    payload = data.get('payload', {})
    
    try:
        if cmd_type == 'MOUSE':
            if action == 'move':
                dx = int(payload.get('dx', 0))
                dy = int(payload.get('dy', 0))
                pyautogui.move(dx, dy)
            elif action == 'click':
                button = payload.get('button', 'left')
                pyautogui.click(button=button)
            elif action == 'scroll':
                amount = int(payload.get('amount', 0))
                pyautogui.scroll(amount)
            elif action == 'double_click':
                pyautogui.doubleClick()
                
        elif cmd_type == 'SYSTEM':
            if action == 'shutdown':
                if system_os == 'Darwin':
                    os.system("sudo shutdown -h now")
                elif system_os == 'Windows':
                    os.system("shutdown /s /t 0")
            elif action == 'restart':
                if system_os == 'Darwin':
                    os.system("sudo shutdown -r now")
                elif system_os == 'Windows':
                    os.system("shutdown /r /t 0")
            elif action == 'sleep':
                if system_os == 'Darwin':
                    os.system("pmset sleepnow")
                elif system_os == 'Windows':
                    os.system("rundll32.exe powrprof.dll,SetSuspendState 0,1,0")
            elif action == 'lock':
                if system_os == 'Darwin':
                    os.system("pmset displaysleepnow")
                elif system_os == 'Windows':
                    os.system("rundll32.exe user32.dll,LockWorkStation")
                
        elif cmd_type == 'APPS':
            if action == 'open_browser':
                if system_os == 'Darwin':
                    os.system("open -a Safari")
                elif system_os == 'Windows':
                    os.system("start msedge")
            elif action == 'open_chrome':
                if system_os == 'Darwin':
                    os.system("open -a 'Google Chrome'")
                elif system_os == 'Windows':
                    os.system("start chrome")
            elif action == 'open_safari':
                if system_os == 'Darwin':
                    os.system("open -a Safari")
            elif action == 'open_brave':
                if system_os == 'Darwin':
                    os.system("open -a 'Brave Browser'")
                elif system_os == 'Windows':
                    os.system("start brave")
            elif action == 'open_terminal':
                if system_os == 'Darwin':
                    os.system("open -a Terminal")
                elif system_os == 'Windows':
                    os.system("start cmd")
            elif action == 'open_vscode':
                if system_os == 'Darwin':
                    os.system("open -a 'Visual Studio Code'")
                elif system_os == 'Windows':
                    os.system("start code")
            elif action == 'open_finder':
                if system_os == 'Darwin':
                    os.system("open -a Finder")
                elif system_os == 'Windows':
                    os.system("start explorer")
                
        elif cmd_type == 'VOLUME':
            if action == 'volume_up':
                pyautogui.press('volumeup')
            elif action == 'volume_down':
                pyautogui.press('volumedown')
            elif action == 'mute':
                pyautogui.press('volumemute')
                
        elif cmd_type == 'SCREENSHOT':
            if action == 'screenshot':
                screenshot = pyautogui.screenshot()
                buffered = io.BytesIO()
                screenshot.save(buffered, format="JPEG")
                img_str = base64.b64encode(buffered.getvalue()).decode()
                emit('screenshot_result', {'image': img_str})
                
        elif cmd_type == 'STREAM':
            if action == 'start':
                start_stream(socketio, request.sid)
            elif action == 'stop':
                stop_stream()
            elif action == 'change_monitor':
                set_monitor(payload.get('monitor_index', 1))
                
        elif cmd_type == 'KEYBOARD':
            if action == 'type_text':
                text = payload.get('text', '')
                pyautogui.write(text)
            elif action == 'key_press':
                key = payload.get('key')
                if key.startswith('command+'):
                    char = key.split('+')[1]
                    modifier = 'command' if system_os == 'Darwin' else 'ctrl'
                    pyautogui.hotkey(modifier, char)
                else:
                    pyautogui.press(key)
                    
        elif cmd_type == 'MEDIA':
            if action in ['playpause', 'next', 'prev']:
                media_action(action)
                
        elif cmd_type == 'VOICE':
            text = payload.get('text', '').lower()
            if 'chrome' in text:
                if system_os == 'Darwin': os.system("open -a 'Google Chrome'")
            elif 'close' in text:
                if system_os == 'Darwin': pyautogui.hotkey('command', 'w')
                else: pyautogui.hotkey('alt', 'f4')
            elif 'volume up' in text:
                pyautogui.press('volumeup')
            elif 'volume down' in text:
                pyautogui.press('volumedown')
            elif 'screenshot' in text:
                screenshot = pyautogui.screenshot()
                buffered = io.BytesIO()
                screenshot.save(buffered, format="JPEG")
                emit('screenshot_result', {'image': base64.b64encode(buffered.getvalue()).decode()})
            elif 'sleep' in text:
                if system_os == 'Darwin': os.system("pmset sleepnow")
            elif 'shutdown' in text:
                if system_os == 'Darwin': os.system("sudo shutdown -h now")
            elif 'scroll up' in text:
                pyautogui.scroll(10)
            elif 'scroll down' in text:
                pyautogui.scroll(-10)
            elif 'next song' in text:
                media_action('next')
            elif 'pause' in text or 'play' in text:
                media_action('playpause')
                
        elif cmd_type == 'MACRO':
            if action == 'play':
                play_macro(payload.get('actions', []))
                
        elif cmd_type == 'SCHEDULE':
            if action == 'add':
                schedule_action(payload.get('action'), payload.get('run_date'))
                emit('schedule_update', get_scheduled_jobs())
            elif action == 'get':
                emit('schedule_update', get_scheduled_jobs())
                
        elif cmd_type == 'WINDOWS':
            if action == 'get':
                emit('windows_list', get_windows())
            elif action in ['focus', 'close', 'minimize']:
                window_action(action, payload.get('app'), payload.get('title'))
                time.sleep(0.5)
                emit('windows_list', get_windows())
                
        elif cmd_type == 'PRESENTATION':
            if action == 'laser':
                move_laser(payload.get('x_percent', 0.5), payload.get('y_percent', 0.5))
            elif action == 'hide_laser':
                hide_laser()
            elif action == 'next_slide':
                pyautogui.press('right')
            elif action == 'prev_slide':
                pyautogui.press('left')
            elif action == 'black_screen':
                pyautogui.press('b')
            
    except Exception as e:
        emit('error', {'message': str(e)})

def run_flask():
    try:
        # Use SSL if certificates exist
        if os.path.exists('cert.pem') and os.path.exists('key.pem'):
            socketio.run(app, host='0.0.0.0', port=5000, ssl_context=('cert.pem', 'key.pem'), allow_unsafe_werkzeug=True)
        else:
            socketio.run(app, host='0.0.0.0', port=5000, allow_unsafe_werkzeug=True)
    finally:
        pass

def create_image():
    # Generate a simple icon for pystray
    image = Image.new('RGB', (64, 64), color=(30, 41, 59))
    draw = ImageDraw.Draw(image)
    draw.ellipse((16, 16, 48, 48), fill=(34, 211, 238))
    return image

def on_open_dashboard(icon, item):
    webbrowser.open('http://127.0.0.1:5000')

def on_settings(icon, item):
    if sys.platform == 'win32':
        os.startfile('config.json')
    elif sys.platform == 'darwin':
        os.system('open config.json')
    else:
        os.system('xdg-open config.json')

def on_quit(icon, item):
    icon.stop()
    global zeroconf, info
    if zeroconf and info:
        zeroconf.unregister_service(info)
        zeroconf.close()
    os._exit(0)

zeroconf = None
info = None

if __name__ == '__main__':
    # Initialize default config if not exists
    if not os.path.exists(CONFIG_FILE):
        save_config({'pin': '1234'})
    
    # Setup mDNS
    zeroconf = Zeroconf()
    desc = {'path': '/'}
    info = ServiceInfo(
        "_http._tcp.local.",
        f"{socket.gethostname()}._http._tcp.local.",
        addresses=[socket.inet_aton(get_local_ip())],
        port=5000,
        properties=desc,
        server=f"{socket.gethostname()}.local."
    )
    zeroconf.register_service(info)

    # Start Flask Server in background
    flask_thread = threading.Thread(target=run_flask, daemon=True)
    flask_thread.start()

    # Start System Tray in main thread
    icon = pystray.Icon("PCRemote")
    icon.menu = pystray.Menu(
        pystray.MenuItem("Settings (config.json)", on_settings),
        pystray.MenuItem("Quit", on_quit)
    )
    icon.icon = create_image()
    icon.title = f"PC Remote Server (PIN: {load_config().get('pin')})"
    
    try:
        icon.run()
    except Exception as e:
        print(f"Tray icon failed: {e}")
    
    # Fallback to keep the main thread alive if pystray exits immediately (common on macOS)
    print("Server running in background. Press Ctrl+C to exit.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        if zeroconf and info:
            zeroconf.unregister_service(info)
            zeroconf.close()

