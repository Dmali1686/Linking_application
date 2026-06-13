import io
import base64
from PIL import Image
import threading
import time

try:
    from mss import mss
    sct = mss()
    USE_MSS = True
except ImportError:
    import pyautogui
    USE_MSS = False

stream_thread = None
is_streaming = False
current_monitor_index = 1

def get_monitor_count():
    if USE_MSS:
        # sct.monitors[0] is all monitors combined
        return len(sct.monitors) - 1
    return 1

def set_monitor(index):
    global current_monitor_index
    if USE_MSS:
        if 1 <= index <= len(sct.monitors) - 1:
            current_monitor_index = index

def capture_screen(quality, resolution):
    if USE_MSS:
        sct_img = sct.grab(sct.monitors[current_monitor_index])
        img = Image.frombytes("RGB", sct_img.size, sct_img.bgra, "raw", "BGRX")
    else:
        img = pyautogui.screenshot()
        
    if resolution == 'low':
        img = img.resize((854, 480))
    elif resolution == 'medium':
        img = img.resize((1280, 720))
    elif resolution == 'high':
        img = img.resize((1920, 1080))
        
    buffered = io.BytesIO()
    img.save(buffered, format="JPEG", quality=quality)
    return base64.b64encode(buffered.getvalue()).decode()

def stream_loop(socketio, room):
    global is_streaming
    while is_streaming:
        try:
            start_time = time.time()
            frame = capture_screen(quality=40, resolution='medium')
            socketio.emit('screen_frame', {
                'image': frame,
                'monitor_count': get_monitor_count(),
                'current_monitor': current_monitor_index
            }, to=room)
            
            elapsed = time.time() - start_time
            sleep_time = max(0, 0.1 - elapsed) # 100ms interval
            time.sleep(sleep_time)
        except Exception as e:
            print("Stream error:", e)
            break

def start_stream(socketio, room):
    global stream_thread, is_streaming
    if not is_streaming:
        is_streaming = True
        stream_thread = threading.Thread(target=stream_loop, args=(socketio, room), daemon=True)
        stream_thread.start()

def stop_stream():
    global is_streaming
    is_streaming = False
