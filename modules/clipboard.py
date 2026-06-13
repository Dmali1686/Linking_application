import pyperclip
import time
import threading

def clipboard_loop(socketio, authenticated_sids):
    last_clipboard = ""
    while True:
        try:
            time.sleep(1)
            current_clipboard = pyperclip.paste()
            if current_clipboard != last_clipboard:
                last_clipboard = current_clipboard
                if authenticated_sids:
                    socketio.emit('clipboard_update', {'text': current_clipboard})
        except Exception as e:
            pass # ignore errors, might happen if clipboard is image

def start_clipboard_sync(socketio, authenticated_sids):
    threading.Thread(target=clipboard_loop, args=(socketio, authenticated_sids), daemon=True).start()

def set_clipboard(text):
    try:
        pyperclip.copy(text)
    except Exception as e:
        print("Set clipboard error:", e)
