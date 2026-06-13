import tkinter as tk
import sys

def main():
    root = tk.Tk()
    root.attributes('-alpha', 0.8)
    try:
        root.attributes('-transparent', True)
        root.config(bg='systemTransparent')
    except:
        pass
    
    root.attributes('-topmost', True)
    root.overrideredirect(True)
    
    w = root.winfo_screenwidth()
    h = root.winfo_screenheight()
    root.geometry(f"{w}x{h}+0+0")
    
    canvas = tk.Canvas(root, width=w, height=h, highlightthickness=0)
    canvas.config(bg='gray10') 
    try:
        canvas.config(bg='systemTransparent')
    except:
        pass
    canvas.pack(fill='both', expand=True)
    
    dot = canvas.create_oval(-20, -20, -10, -10, fill='red', outline='red')
    
    def check_input():
        import select
        while select.select([sys.stdin], [], [], 0)[0]:
            line = sys.stdin.readline()
            if not line:
                root.quit()
                return
            line = line.strip()
            if line == 'hide':
                canvas.coords(dot, -20, -20, -10, -10)
            else:
                try:
                    xp, yp = map(float, line.split(','))
                    x = w * xp
                    y = h * yp
                    r = 15
                    canvas.coords(dot, x-r, y-r, x+r, y+r)
                except:
                    pass
        root.after(10, check_input)
        
    root.after(10, check_input)
    root.mainloop()

if __name__ == '__main__':
    main()
