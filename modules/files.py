import os
import math

def format_size(size):
    if size == 0:
        return "0 B"
    units = ["B", "KB", "MB", "GB", "TB"]
    i = int(math.floor(math.log(size, 1024)))
    p = math.pow(1024, i)
    s = round(size / p, 2)
    return f"{s} {units[i]}"

def get_files_list(path=None):
    if not path:
        path = os.path.expanduser("~")
        
    try:
        items = []
        for item in os.listdir(path):
            if item.startswith('.'):
                continue # Skip hidden files
            full_path = os.path.join(path, item)
            is_dir = os.path.isdir(full_path)
            try:
                size = os.path.getsize(full_path) if not is_dir else 0
            except OSError:
                size = 0
                
            items.append({
                'name': item,
                'path': full_path,
                'is_dir': is_dir,
                'size': format_size(size)
            })
        # Sort directories first, then alphabetically
        items.sort(key=lambda x: (not x['is_dir'], x['name'].lower()))
        
        parent_dir = os.path.dirname(path) if path != '/' else None
        
        return {'status': 'success', 'path': path, 'parent_dir': parent_dir, 'items': items}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

def save_uploaded_file(filename, file_data):
    downloads_folder = os.path.join(os.path.expanduser("~"), "Downloads")
    if not os.path.exists(downloads_folder):
        os.makedirs(downloads_folder)
        
    file_path = os.path.join(downloads_folder, filename)
    with open(file_path, 'wb') as f:
        f.write(file_data)
        
    return file_path
