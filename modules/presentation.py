import subprocess
import threading
import sys
import os

overlay_process = None

def init_overlay():
    global overlay_process
    script_path = os.path.join(os.path.dirname(__file__), 'laser_overlay.py')
    overlay_process = subprocess.Popen([sys.executable, script_path], stdin=subprocess.PIPE, text=True)

def start_presentation_overlay():
    threading.Thread(target=init_overlay, daemon=True).start()

def move_laser(x_percent, y_percent):
    if overlay_process and overlay_process.stdin:
        try:
            overlay_process.stdin.write(f"{x_percent},{y_percent}\n")
            overlay_process.stdin.flush()
        except:
            pass

def hide_laser():
    if overlay_process and overlay_process.stdin:
        try:
            overlay_process.stdin.write("hide\n")
            overlay_process.stdin.flush()
        except:
            pass
