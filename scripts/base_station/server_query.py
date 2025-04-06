import serial
import requests
import re
import time
from datetime import datetime, timezone
from dateutil.parser import isoparse

# Supabase URL and API key
SUPABASE_URL = "https://mgrgaxqqtvqttxvulbnk.supabase.co"
SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ncmdheHFxdHZxdHR4dnVsYm5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzc0MDUyMDgsImV4cCI6MjA1Mjk4MTIwOH0.A3VybPyJGZ3Bm2rfe1BMZLM_51eVKFmW0uEGSi6qZhI'

# Serial port and baud rate
PORT = '/dev/tty.usbmodem101'  
BAUD_RATE = 115200          

# Message Types
ACK = 0
SEND_GPS = 1
REQUEST_GPS = 2
MODE_TOGGLE = 3
SPEAKER_ON = 4
SPEAKER_OFF = 5
SEND_BATTERY = 6
REQUEST_BATTERY = 7
SLEEP = 8

def send_command(command):
        print(f"Sending command to LoRa server: {command}\n")
        server.write(f"{command}\n".encode('utf-8'))

def main():
    try:
        global mode
        global server
        server = serial.Serial(PORT, BAUD_RATE)
        print(f"Connected to {PORT} at {BAUD_RATE} baud")
        
        mode = 'n'
        print('Starting in Normal Mode')

        time.sleep(2)  # Allow time for connection
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
        exit(1)

    while True:
        while server.in_waiting > 0:
            # Read data from base station
            print("Reading from LoRa server...")
            data = {}
            message = server.readline().decode('utf-8').strip()
            # message = server.read(server.in_waiting).decode('utf-8').strip()
            print(f"Received from LoRa server: {message}\n")

            if ("GPS" in message):
                neg = -1
                lat_str = message.split("SEND_GPS_LAT")[1].split("SEND_GPS_LONG")[0]
                lon_str = message.split("SEND_GPS_LONG")[1]

                # Remove any non-numeric characters (just in case)
                lat_digits = ''.join(re.findall(r'\d+', lat_str))
                lon_digits = ''.join(re.findall(r'\d+', lon_str))

                print(f"Latitude string: {lat_digits}")
                print(f"Longitude string: {neg*lon_digits}")
                data = {"gps_latitude": lat_digits, "gps_longitude": neg*lon_digits}
            if ("SEND_BATTERY" in message):
                _, _, level = message.lstrip().partition(' ')
                print("Battery")
                print(level)
                data = {"battery_level": level}

            if ("SLEEP" in message):
                data = {"sleep": True}


            if data:
                print(f"Sending to Supabase\n")

                response = requests.post(
                    f"{SUPABASE_URL}/rest/v1/device_status",
                    headers={
                        "Content-Type": "application/json",
                        "apikey": SUPABASE_KEY,  # Add the API key here
                    },
                    json=data
                )

                if response.text.strip():  # Ensure there is content to parse
                    try:
                        data = response.json()
                        print("Parsed JSON Data:", data)
                    except requests.exceptions.JSONDecodeError as e:
                        print("Error parsing JSON:", e)
                else:
                    print("Empty response body.")
                print("\n")

        # Read data from Supabase, sort by deceasing order of timestamp and only look at unprocessed commands
        commands = requests.get(
            f"{SUPABASE_URL}/rest/v1/device_commands?select=&status=eq.false&order=timestamp.desc&apikey={SUPABASE_KEY}",
            headers={"Content-Type": "application/json"}
        )
        
        print(f"Supabase Status: {commands.status_code} \nSupabase Command: {commands.json()} \n")

        if commands.status_code == 200 and commands.json():
            commands = commands.json()

            for command in commands:
                command_id = command['id']

                # Parse command, allow buzzer, update_battery, mode
                if command['battery']: send_command("battery")
                if command['gps']: send_command("gps")
                if command['mode']:
                    if mode !=  command['mode']:
                        print(f"Sending {command['mode']} mode to LoRa server.") 
                        send_command("mode")
                if not (command['buzzer'] is None):
                    timestamp = isoparse(command['timestamp'])
                    now = datetime.now(timezone.utc)

                    if ( abs((now - timestamp).total_seconds()) <= 30):
                        print("Buzzer command within 30 seconds")
                        if (command['buzzer']):
                            send_command("buzzer_on") # fix how this toggles, just push through if either is not null, need to also filter for unprocessed commands in the future
                        else:
                            send_command("buzzer_off")
                
                    if (command['buzzer']):
                        send_command("buzzer_on") # fix how this toggles, just push through if either is not null, need to also filter for unprocessed commands in the future
                    else:
                        send_command("buzzer_off")

                # After sending, mark this command as processed in Supabase
                update = requests.patch(
                    f"{SUPABASE_URL}/rest/v1/device_commands?id=eq.{command_id}&apikey={SUPABASE_KEY}",
                    headers={"Content-Type": "application/json"},
                    json={"status": True}
                )

                if update.status_code // 100 == 2:  # Check if status code is in the 2xx range
                    print(f"Command {command_id} marked as processed.\n")
                else:
                    print(f"Failed to update command {command_id} status with code {update.status_code}.\n")
        else:
            print("No new unprocessed commands. \n")

        # Wait before checking for new commands
        time.sleep(2) # Slowly now for testing

if __name__ == "__main__":
    main()