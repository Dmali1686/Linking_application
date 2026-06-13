import platform
import subprocess
import os

system_os = platform.system()

def get_windows():
    windows = []
    if system_os == 'Darwin':
        script = """
        tell application "System Events"
            set out to ""
            set allProcesses to (every process whose visible is true)
            repeat with proc in allProcesses
                try
                    set procName to name of proc
                    set procWindows to (every window of proc)
                    repeat with win in procWindows
                        set winName to name of win
                        if winName is not "" then
                            set out to out & procName & "|||" & winName & "\\n"
                        end if
                    end repeat
                end try
            end repeat
            return out
        end tell
        """
        try:
            result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines:
                    if '|||' in line:
                        app, title = line.split('|||', 1)
                        windows.append({'app': app.strip(), 'title': title.strip()})
            else:
                if 'Not authorised' in result.stderr:
                    windows.append({'app': 'Error', 'title': 'macOS Accessibility Permission Required for System Events'})
        except Exception as e:
            windows.append({'app': 'Error', 'title': str(e)})

    elif system_os == 'Windows':
        # Fallback using PowerShell if pygetwindow is not installed
        ps_script = 'Get-Process | Where-Object {$_.MainWindowTitle -ne ""} | Select-Object Name, MainWindowTitle | ConvertTo-Json'
        try:
            result = subprocess.run(['powershell', '-Command', ps_script], capture_output=True, text=True)
            if result.returncode == 0 and result.stdout.strip():
                import json
                data = json.loads(result.stdout)
                if isinstance(data, dict):
                    data = [data]
                for item in data:
                    windows.append({'app': item.get('Name', 'Unknown'), 'title': item.get('MainWindowTitle', '')})
        except Exception as e:
            windows.append({'app': 'Error', 'title': str(e)})
            
    return windows

def window_action(action, app_name=None, title=None):
    if system_os == 'Darwin':
        if action == 'focus' and app_name:
            script = f'tell application "{app_name}" to activate'
            subprocess.run(['osascript', '-e', script])
        elif action == 'close' and app_name and title:
            script = f'''
            tell application "{app_name}"
                close (every window whose name is "{title}")
            end tell
            '''
            subprocess.run(['osascript', '-e', script])
        elif action == 'minimize' and app_name and title:
            script = f'''
            tell application "{app_name}"
                set (miniaturized of every window whose name is "{title}") to true
            end tell
            '''
            subprocess.run(['osascript', '-e', script])

    elif system_os == 'Windows':
        if action == 'focus' and title:
            ps_script = f'''
            Add-Type -AssemblyName VisualBasic
            [Microsoft.VisualBasic.Interaction]::AppActivate("{title}")
            '''
            subprocess.run(['powershell', '-Command', ps_script])
        elif action == 'close' and title:
            ps_script = f'Get-Process | Where-Object {{$_.MainWindowTitle -eq "{title}"}} | Stop-Process'
            subprocess.run(['powershell', '-Command', ps_script])
        # Minimize via PowerShell is complex, usually involves C# signatures. We'll skip for now or use generic approach.
