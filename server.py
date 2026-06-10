import os
import subprocess
import base64
import io
import json
import socket
import threading
import platform
import tkinter as tk
from tkinter import ttk, messagebox
import pyautogui
import qrcode
from PIL import Image, ImageTk
from flask import Flask, render_template, request, send_from_directory
from flask_socketio import SocketIO, emit
from zeroconf import ServiceInfo, Zeroconf

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

@socketio.on('connect')
def test_connect():
    pass

@socketio.on('disconnect')
def test_disconnect():
    if request.sid in authenticated_sids:
        authenticated_sids.remove(request.sid)

@socketio.on('authenticate')
def handle_authenticate(data):
    pin = data.get('pin')
    if pin == PIN:
        authenticated_sids.add(request.sid)
        emit('authenticated', {'status': 'success'})
    else:
        emit('authenticated', {'status': 'fail'})

def is_authenticated():
    return request.sid in authenticated_sids

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
    except Exception as e:
        emit('error', {'message': str(e)})

def run_flask():
    # Use debug=False to prevent Werkzeug from starting a second process which breaks Tkinter
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)

class RemoteApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Remote Control Server")
        self.root.geometry("450x650")
        self.root.resizable(False, False)
        
        self.current_frame = None
        self.zeroconf = None
        
        # Check if config exists for first-time setup
        if not os.path.exists(CONFIG_FILE):
            self.show_setup_screen()
        else:
            self.start_server_and_show_main()

    def show_setup_screen(self):
        if self.current_frame:
            self.current_frame.destroy()
            
        self.current_frame = ttk.Frame(self.root, padding=20)
        self.current_frame.pack(fill="both", expand=True)
        
        # Welcome Header
        header = ttk.Label(self.current_frame, text="Welcome to Remote Control", font=("Inter", 20, "bold"))
        header.pack(pady=(50, 20))
        
        inst_label = ttk.Label(self.current_frame, text="To secure your computer, please set a numeric PIN.\nYou will need to enter this on your phone to connect.", 
                              font=("Inter", 12), justify="center")
        inst_label.pack(pady=(0, 40))
        
        # PIN Entry
        pin_label = ttk.Label(self.current_frame, text="Create Security PIN:", font=("Inter", 14))
        pin_label.pack(pady=(0, 10))
        
        self.setup_pin_var = tk.StringVar()
        pin_entry = ttk.Entry(self.current_frame, textvariable=self.setup_pin_var, font=("Inter", 16), width=12, show="*")
        pin_entry.pack(pady=(0, 30))
        
        # Start Button
        start_btn = ttk.Button(self.current_frame, text="Save & Start Server", command=self.complete_setup)
        start_btn.pack(pady=10)

    def complete_setup(self):
        global PIN
        new_pin = self.setup_pin_var.get()
        if len(new_pin) < 4:
            messagebox.showerror("Error", "PIN must be at least 4 characters.")
            return
            
        PIN = new_pin
        config['pin'] = PIN
        save_config(config)
        self.start_server_and_show_main()

    def start_server_and_show_main(self):
        # Start server in background thread
        self.server_thread = threading.Thread(target=run_flask, daemon=True)
        self.server_thread.start()
        
        # Start Zeroconf broadcasting
        try:
            self.zeroconf = Zeroconf()
            hostname = socket.gethostname().split('.')[0]
            desc = {'path': '/'}
            self.zeroconf_info = ServiceInfo(
                "_remotecontrol._tcp.local.",
                f"{hostname}._remotecontrol._tcp.local.",
                addresses=[socket.inet_aton(local_ip)],
                port=5000,
                properties=desc,
                server=f"{hostname}.local.",
            )
            self.zeroconf.register_service(self.zeroconf_info)
        except Exception as e:
            print(f"Failed to start Zeroconf: {e}")

        self.show_main_screen()

    def show_main_screen(self):
        if self.current_frame:
            self.current_frame.destroy()
            
        self.current_frame = ttk.Frame(self.root, padding=20)
        self.current_frame.pack(fill="both", expand=True)

        # Header
        header = ttk.Label(self.current_frame, text="Remote Control Active", font=("Inter", 24, "bold"))
        header.pack(pady=(10, 10))
        
        # URL Status
        url_label = ttk.Label(self.current_frame, text=f"Connect to: {server_url}", font=("Inter", 14))
        url_label.pack(pady=5)
        
        # Instruction
        inst_label = ttk.Label(self.current_frame, text="Scan this QR code with your phone's camera", font=("Inter", 12))
        inst_label.pack(pady=(0, 20))
        
        # QR Code
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=8,
            border=2,
        )
        qr.add_data(server_url)
        qr.make(fit=True)
        
        qr_img = qr.make_image(fill_color="black", back_color="white")
        self.qr_photo = ImageTk.PhotoImage(qr_img)
        
        qr_label = ttk.Label(self.current_frame, image=self.qr_photo)
        qr_label.pack(pady=10)
        
        # Pin Configuration Frame
        pin_frame = ttk.Frame(self.current_frame)
        pin_frame.pack(pady=30)
        
        pin_label = ttk.Label(pin_frame, text="Security PIN:", font=("Inter", 14))
        pin_label.grid(row=0, column=0, padx=10)
        
        self.pin_var = tk.StringVar(value=PIN)
        self.pin_entry = ttk.Entry(pin_frame, textvariable=self.pin_var, font=("Inter", 14), width=10, show="*")
        self.pin_entry.grid(row=0, column=1, padx=10)
        
        save_btn = ttk.Button(pin_frame, text="Update PIN", command=self.update_pin)
        save_btn.grid(row=0, column=2, padx=10)
        
        # Exit Button
        exit_btn = ttk.Button(self.current_frame, text="Stop Server & Exit", command=self.on_close)
        exit_btn.pack(side="bottom", pady=20)

    def update_pin(self):
        global PIN
        new_pin = self.pin_var.get()
        if len(new_pin) < 4:
            messagebox.showerror("Error", "PIN must be at least 4 characters.")
            return
            
        PIN = new_pin
        config['pin'] = PIN
        save_config(config)
        messagebox.showinfo("Success", "PIN updated successfully!")

    def on_close(self):
        if self.zeroconf:
            try:
                self.zeroconf.unregister_service(self.zeroconf_info)
                self.zeroconf.close()
            except Exception:
                pass
        self.root.quit()

if __name__ == '__main__':
    root = tk.Tk()
    app_gui = RemoteApp(root)
    root.protocol("WM_DELETE_WINDOW", app_gui.on_close)
    root.mainloop()
