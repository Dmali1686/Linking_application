# PC Remote Control System

A powerful Remote Control ecosystem containing a Desktop Agent (Python) and a Mobile Client (Flutter).

## Features
- **Dashboard**: Real-time PC stats (CPU, RAM, Storage, Battery, Network).
- **Screen Stream**: Live low-latency screen streaming with Tap-to-Click.
- **Control**: Trackpad, Keyboard, System Controls (Sleep, Shutdown, Lock).
- **Files & Clipboard**: Browse PC files, upload/download files, sync clipboard.
- **Media & Voice**: Control Spotify/Apple Music, Voice Commands via speech recognition.
- **Macros & Scheduling**: Automate actions and schedule system tasks (APScheduler).
- **Presentation Mode**: Slide controller with an interactive Virtual Laser Pointer.
- **Security**: Self-signed SSL, WSS, Rate-Limiting, Session Tokens.
- **Wake on LAN**: Remotely wake your PC via Magic Packet.

## Installation & Running

### Desktop Agent
1. Install Python 3.
2. Install dependencies: `pip install -r requirements.txt` (You may need to run `pip install pystray Pillow pyinstaller`).
3. Run the server: `python server.py`
4. A System Tray icon will appear. Check `config.json` for your PIN.

#### Build Standalone Executable
You can compile the Desktop Agent into a standalone executable so you don't need Python installed.
- **Mac/Linux**: Run `./build.sh`
- **Windows**: Run `build.bat`
The compiled app will be placed in `dist/server/`.

### Mobile App
1. Install Flutter.
2. Navigate to `mobile_app` folder.
3. Run `flutter pub get`
4. Run `flutter run` on your device.

## Usage
- Ensure both devices are on the same WiFi network.
- The mobile app will auto-discover the PC via mDNS.
- Enter your PIN (Default: 1234, configurable in config.json).
- On first successful connection, a token is saved. Future connections will bypass the PIN screen automatically!
