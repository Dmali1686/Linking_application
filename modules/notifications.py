import threading
import time
import datetime

def notifications_loop(socketio, authenticated_sids):
    # Dummy loop that sends a test notification every 30 seconds
    while True:
        try:
            time.sleep(30)
            if authenticated_sids:
                notification = {
                    'app': 'System',
                    'title': 'Test Notification',
                    'message': 'This is a test notification from your PC.',
                    'time': datetime.datetime.now().strftime("%H:%M:%S")
                }
                socketio.emit('notification', notification)
        except Exception as e:
            print("Notifications error:", e)

def start_notifications_sync(socketio, authenticated_sids):
    threading.Thread(target=notifications_loop, args=(socketio, authenticated_sids), daemon=True).start()
