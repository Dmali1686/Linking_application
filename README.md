# Mac Remote Control

A local PC Remote Control application for macOS. This app allows you to control your Mac from your mobile device using a web browser. It features a dark-themed, modern interface with a full touchpad, keyboard input, media controls, and system actions.

## Prerequisites

- macOS (any version)
- Python 3.8+ (If you don't have Python, install it via Homebrew: `brew install python3`)
- Your Mac and mobile device must be on the same WiFi network (for local access).

## Installation

1. Open your Terminal on macOS.
2. Navigate to this folder.
3. Install the required Python libraries using pip:

```bash
pip3 install flask flask-socketio pyautogui Pillow
```

## macOS Permissions

For the app to control your mouse, keyboard, and take screenshots, you must grant Terminal some permissions.

1. **Accessibility**:
   - Open **System Settings** -> **Privacy & Security** -> **Accessibility**
   - Enable your Terminal app (e.g., Terminal, iTerm).
2. **Screen Recording**:
   - Open **System Settings** -> **Privacy & Security** -> **Screen Recording**
   - Enable your Terminal app (required for taking screenshots).

## Running the Server

1. Start the server from your Terminal:

```bash
python3 server.py
```

2. The server will start on port `5000`.

## Connecting from Mobile (Local Network)

1. Find your Mac's IP address by running the following command in a new Terminal window:

```bash
ipconfig getifaddr en0
```
*(Alternatively, find it in System Settings -> Wi-Fi -> Details -> IP Address)*

2. Open the web browser (Safari/Chrome) on your mobile device.
3. Enter the URL: `http://YOUR_MAC_IP:5000` (e.g., `http://192.168.1.5:5000`)
4. Enter the default PIN: `1234` to unlock the remote.

## Remote Access (Outside Home)

If you want to control your Mac when you are not on the same Wi-Fi network, you can use Ngrok to expose your local server securely over the internet.

1. Install Ngrok via Homebrew:

```bash
brew install ngrok
```

2. Expose port 5000:

```bash
ngrok http 5000
```

3. Ngrok will provide a public Forwarding URL (e.g., `https://abc-123.ngrok-free.app`). Open this URL on your mobile browser anywhere in the world to access the remote control.

## Tech Stack

- **Backend**: Python, Flask, Flask-SocketIO, PyAutoGUI, Pillow.
- **Frontend**: HTML5, CSS3, JavaScript, Socket.IO CDN.
