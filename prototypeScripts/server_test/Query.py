import serial
import requests
import time

SUPABASE_URL = "https://mgrgaxqqtvqttxvulbnk.supabase.co"
SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ncmdheHFxdHZxdHR4dnVsYm5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzc0MDUyMDgsImV4cCI6MjA1Mjk4MTIwOH0.A3VybPyJGZ3Bm2rfe1BMZLM_51eVKFmW0uEGSi6qZhI'

# Open serial connection to LoRa server
port = '/dev/tty.usbmodem1101'  
baudrate = 115200            

try:
    server = serial.Serial(port, baudrate)
    print(f"Connected to {port} at {baudrate} baud")
    time.sleep(2)  # Allow time for connection
except serial.SerialException as e:
    print(f"Error opening serial port: {e}")
    exit(1)

headers = {
    "Content-Type": "application/json",
}


while True:
    while server.in_waiting > 0:

        # Read data from Arduino
        print("Reading from LoRa server...")
        # message = server.readline().decode('utf-8').strip()
        message = server.read(server.in_waiting).decode('utf-8').strip()
        print(f"Received from LoRa server: {message}")

        # Parse later, for now test
        data = {"test_message": message}

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
        headers=headers
    )
    
    print("Supabase Command Response:", commands.status_code, commands.json())
    print("\n")

    if commands.status_code == 200 and commands.json():
        commands = commands.json()

        for command in commands:
            command_id = command['id']
            print(command_id)

            
            # Send the command to LoRa server
            print(f"Sending command to LoRa server: {command}")
            print("\n")
            server.write(f"b\n".encode('utf-8'))

            # After sending, mark this command as processed in Supabase
            # turned off for now to test
            # update_response = requests.patch(
            #     f"{SUPABASE_URL}/rest/v1/device_commands?id=eq.{command_id}",
            #     headers=headers,
            #     json={"processed": True}
            # )
            
            # if update_response.status_code == 200:
            #     print(f"Command {command_id} marked as processed.")
            # else:
            #     print(f"Failed to update command {command_id} status.")
    else:
        print("No new unprocessed commands.")

    # Wait before checking for new commands
    time.sleep(2) # slowly now for testing
