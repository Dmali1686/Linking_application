import platform
import subprocess
import threading
import time

def get_mac_media_info():
    script = '''
    try
        tell application "Spotify"
            if player state is playing then
                set trackName to name of current track
                set artistName to artist of current track
                return trackName & " - " & artistName
            end if
        end tell
    end try
    try
        tell application "Music"
            if player state is playing then
                set trackName to name of current track
                set artistName to artist of current track
                return trackName & " - " & artistName
            end if
        end tell
    end try
    return ""
    '''
    try:
        output = subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
        if output:
            parts = output.split(' - ', 1)
            return {'title': parts[0], 'artist': parts[1] if len(parts) > 1 else 'Unknown', 'playing': True}
    except Exception:
        pass
    return {'title': 'Not Playing', 'artist': '', 'playing': False}

def media_action(action):
    if platform.system() == 'Darwin':
        # Default to Spotify for mac media controls for simplicity
        if action == 'playpause':
            subprocess.run(['osascript', '-e', 'tell application "Spotify" to playpause'])
        elif action == 'next':
            subprocess.run(['osascript', '-e', 'tell application "Spotify" to next track'])
        elif action == 'prev':
            subprocess.run(['osascript', '-e', 'tell application "Spotify" to previous track'])

def media_loop(socketio, authenticated_sids):
    last_info = None
    while True:
        try:
            time.sleep(2)
            if not authenticated_sids:
                continue
                
            info = None
            if platform.system() == 'Darwin':
                info = get_mac_media_info()
            
            if info and info != last_info:
                last_info = info
                socketio.emit('media_update', info)
        except Exception as e:
            print("Media loop error:", e)

def start_media_sync(socketio, authenticated_sids):
    threading.Thread(target=media_loop, args=(socketio, authenticated_sids), daemon=True).start()
