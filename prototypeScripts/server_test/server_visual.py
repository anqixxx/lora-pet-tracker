from flask import Flask, render_template, request
from supabase import create_client
from pytz import timezone
from datetime import datetime
from typing import List, Dict

SUPABASE_URL = "https://mgrgaxqqtvqttxvulbnk.supabase.co"
SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ncmdheHFxdHZxdHR4dnVsYm5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzc0MDUyMDgsImV4cCI6MjA1Mjk4MTIwOH0.A3VybPyJGZ3Bm2rfe1BMZLM_51eVKFmW0uEGSi6qZhI'
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

def filter_app(app_data):
    filtered = list(dict())

    for data in app_data:
        filtered_data = {'id': data['id'], 'timestamp': data['timestamp'], 'status': status(data['status']), 'msg': None}
        command = str()

        info_keys = ['buzzer', 'mode', 'battery', 'gps']
        non_none_pairs = [(key, data[key]) for key in info_keys if data.get(key) is not None]
        
        for pair in non_none_pairs:
            if pair[0] == 'buzzer':
                if pair[1]:
                    command += str('Request Buzzer On')
                else:
                    command += str('Request Buzzer On')
            elif pair[0] == 'mode':
                command += str(f'Request Mode {pair[1]}')
            else:
                command += str(f'Request {pair[0]} data')

        filtered_data['msg'] = command
        filtered.append(filtered_data)
    
    return filtered

def filter_node(node_data):
    filtered = list(dict())

    for data in node_data:
        filtered_data = {'id': data['id'], 'timestamp': data['timestamp'], 'gps_latitude': data['gps_latitude'], 'gps_longitude': data['gps_longitude'], 'battery_level': data['battery_level'], 'msg': None}
        msg = str()
        
        if data['test_message']:
            msg += str(data['test_message']) + '\n'
        if data['sleep_mode']:
            msg += 'Sleep mode turned on'
            
        filtered_data['msg'] = msg
        filtered.append(filtered_data)
    
    return filtered

def status(stat):
    if stat:
        return 'Unsent'
    else:
        return 'Sent'

def format_datetime(value, target_tz='America/Los_Angeles'):
    dt = datetime.fromisoformat(value)
    dt = dt.astimezone(timezone(target_tz))
    return dt.strftime(f"%b %d, %Y - %I:%M:%S %p")

app = Flask(__name__)

app.jinja_env.filters['datetime'] = format_datetime

@app.route('/')
def dashboard():
    # Fetch GPS data from Supabase
    user_id = None
    mode = request.args.get('mode')  # Get mode from query parameters

    if mode and mode.lower() == 'test':
        user_id = 1
    elif mode and mode.lower() == 'exp':
        user_id = 2
    
    print(f'mode updated: {mode}')

    node_data = supabase.from_('device_status').select('*').execute().data  
    app_data = supabase.from_('device_commands').select('*').execute().data  

    node_data = filter_node(node_data)
    app_data = filter_app(app_data)

    return render_template('dashboard.html', node_data=node_data, app_data=app_data, mode=mode, user_id=user_id)

if __name__ == '__main__':
    app.run(debug=True)

