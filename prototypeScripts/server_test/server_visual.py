from flask import Flask, render_template, request
from supabase import create_client
from pytz import timezone
from datetime import datetime
from typing import List, Dict

SUPABASE_URL = "https://mgrgaxqqtvqttxvulbnk.supabase.co"
SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ncmdheHFxdHZxdHR4dnVsYm5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzc0MDUyMDgsImV4cCI6MjA1Mjk4MTIwOH0.A3VybPyJGZ3Bm2rfe1BMZLM_51eVKFmW0uEGSi6qZhI'
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

app = Flask(__name__)

from flask import request, render_template

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
    app_data = filter_app(app_data)
    print(type(app_data[0]))
    return render_template('dashboard.html', node_data=node_data, app_data=app_data, mode=mode, user_id=user_id)

def filter_app(app_data):
    # status
    filtered = list(dict())

    for data in app_data:
        filtered_data = {'id': data['id'], 'timestamp': data['timestamp'], 'status': data['status'], 'msg': None}
        command = str()

        info_keys = ['buzzer', 'mode', 'battery', 'gps']
        non_none_pairs = [(key, data[key]) for key in info_keys if data.get(key) is not None]
        
        for pair in non_none_pairs:
            print(type(pair))
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

def format_datetime(value, target_tz='UTC'):
    dt = datetime.fromisoformat(value)
    dt = dt.astimezone(timezone(target_tz))
    return dt.strftime(f"%B %d, %Y at %H:%M:%S {target_tz}")

if __name__ == '__main__':
    app.run(debug=True)

