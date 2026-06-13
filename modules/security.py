import os
import json
import secrets
import time

FAILED_ATTEMPTS = {}
MAX_ATTEMPTS = 5
LOCKOUT_TIME = 300 # 5 minutes
TOKENS = set()

def check_rate_limit(ip):
    record = FAILED_ATTEMPTS.get(ip)
    if record:
        if record['count'] >= MAX_ATTEMPTS:
            if time.time() - record['last_time'] < LOCKOUT_TIME:
                return False
            else:
                FAILED_ATTEMPTS[ip] = {'count': 0, 'last_time': time.time()}
    return True

def record_failed_attempt(ip):
    record = FAILED_ATTEMPTS.get(ip, {'count': 0, 'last_time': time.time()})
    record['count'] += 1
    record['last_time'] = time.time()
    FAILED_ATTEMPTS[ip] = record

def reset_attempts(ip):
    if ip in FAILED_ATTEMPTS:
        del FAILED_ATTEMPTS[ip]

def generate_token():
    token = secrets.token_hex(16)
    TOKENS.add(token)
    return token

def is_valid_token(token):
    return token in TOKENS
