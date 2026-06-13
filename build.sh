#!/bin/bash

echo "Installing PyInstaller..."
pip3 install pyinstaller

echo "Building PC Remote Desktop Agent..."
# We use --windowed to hide the console so the tray icon runs silently.
# We include necessary modules and certificate files.
pyinstaller --noconfirm --onedir --windowed \
    --add-data "cert.pem:." \
    --add-data "key.pem:." \
    --add-data "modules:modules" \
    server.py

echo "Build complete! Your executable is located in the 'dist/server' folder."
echo "You can move this folder anywhere and run the 'server' app."
