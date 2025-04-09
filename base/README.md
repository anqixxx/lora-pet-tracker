LoRa Pet Tracker Base Station
=========

This repository contains the firmware and setup for the LoRa base station component of the LoRa Pet Tracker project. The base station acts as a central hub to receive data from remote pet-tracking nodes via LoRa and relay it to the cloud.

Features
=========

The base station performs the following key functions:

- Listens for uplink LoRa messages from pet nodes.
- Parses GPS, battery, and status data.
- Relays the data to the cloud (Supabase) via UART or I2C.
- Optionally responds to downlink commands (e.g., activate buzzer, request GPS, etc.).

Visual Dashboard
=========

The base station is integrated with a Flask visual dashboard, allowing you to see in real time how the Node, Base, and App Communicate

![Dashboard Overview](images/homepage.png)

Initalization
=========
To activate the base station, follow the following steps:

1. If you have not already, please clone this repo:
   ```bash
   git clone https://github.com/anqixxx/lora-pet-tracker.git
   cd lora-pet-tracker/base 

2. Load the code onto the MCU using server.ino with your IDE of choice. We used the Arduino IDE.

3. Run server_query to create the connection with the Backend Supabase PostGreSQL server
   ```python  server_query.py

4. [Optional] Run the visual dashboard
   ```python server_visual.py 