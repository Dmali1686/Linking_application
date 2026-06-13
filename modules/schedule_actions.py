from apscheduler.schedulers.background import BackgroundScheduler
import os
import platform
from datetime import datetime

scheduler = BackgroundScheduler()
scheduler.start()

def get_scheduled_jobs():
    jobs = []
    for job in scheduler.get_jobs():
        jobs.append({
            'id': job.id,
            'name': job.name,
            'next_run_time': job.next_run_time.isoformat() if job.next_run_time else None
        })
    return jobs

def execute_scheduled_action(action):
    system_os = platform.system()
    if action == 'sleep':
        if system_os == 'Darwin': os.system("pmset sleepnow")
    elif action == 'shutdown':
        if system_os == 'Darwin': os.system("sudo shutdown -h now")

def schedule_action(action, run_date):
    dt = datetime.fromisoformat(run_date)
    scheduler.add_job(
        execute_scheduled_action, 
        'date', 
        run_date=dt, 
        args=[action],
        name=action
    )
