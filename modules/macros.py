import time
import pyautogui

def play_macro(actions):
    for action in actions:
        delay = action.get('delay', 0)
        if delay > 0:
            time.sleep(delay)
            
        cmd_type = action.get('type')
        if cmd_type == 'move':
            pyautogui.move(action.get('dx', 0), action.get('dy', 0))
        elif cmd_type == 'click':
            pyautogui.click(button=action.get('button', 'left'))
        elif cmd_type == 'key_press':
            pyautogui.press(action.get('key', ''))
        elif cmd_type == 'type_text':
            pyautogui.write(action.get('text', ''))
