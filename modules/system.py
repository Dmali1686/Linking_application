import psutil
import datetime
from psutil._common import bytes2human
import time

def get_pc_stats():
    uptime_seconds = time.time() - psutil.boot_time()
    hours, remainder = divmod(uptime_seconds, 3600)
    minutes, _ = divmod(remainder, 60)
    uptime_str = f"{int(hours)}h {int(minutes)}m"

    battery = psutil.sensors_battery()
    battery_percent = battery.percent if battery else 100
    battery_charging = battery.power_plugged if battery else True

    ram = psutil.virtual_memory()
    ram_percent = ram.percent
    ram_used_gb = round(ram.used / (1024 ** 3), 2)

    disk = psutil.disk_usage('/')
    storage_free_gb = round(disk.free / (1024 ** 3), 2)
    storage_total_gb = round(disk.total / (1024 ** 3), 2)

    try:
        # Dummy values for wifi since real speed test is too slow for 2s polling
        wifi_speed = "50/20 mbps"
    except Exception:
        wifi_speed = "0/0 mbps"

    return {
        "cpu_percent": psutil.cpu_percent(interval=None),
        "ram_percent": ram_percent,
        "ram_used": ram_used_gb,
        "storage_free": storage_free_gb,
        "storage_total": storage_total_gb,
        "battery_percent": battery_percent,
        "battery_charging": battery_charging,
        "uptime": uptime_str,
        "pc_time": datetime.datetime.now().strftime("%H:%M:%S"),
        "wifi_speed": wifi_speed
    }
