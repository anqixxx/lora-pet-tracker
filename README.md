# LoRa Pet Tracker 🐾

The **LoRa Pet Tracker** is a Flutter-based mobile application designed to help pet owners track their pets' location in real-time using LoRa (Long Range) technology. The app integrates with a Supabase backend to fetch GPS data, battery levels, and send commands to the pet tracker device.

---

## Features ✨

- **Real-time GPS Tracking**: View your pet's location on an interactive map.
- **Battery Level Monitoring**: Check the battery status of the pet tracker device.
- **Speaker Control**: Trigger a speaker on the device to help locate your pet.
- **Mode Selection**: Switch between **Normal Mode** and **Search Mode** for different tracking scenarios.
- **History**: View historical location data of your pet.

---

## Getting Started 🚀

### Prerequisites

Before running the app, ensure you have the following:

- **Flutter SDK** installed (version 3.0 or higher).
- A **Supabase account** with a project set up.
- A **LoRa-enabled pet tracker device**.

---

## Usage 🛠️

### Home Screen
- **Map**: Displays your pet's current location and the latest GPS data.
- **Battery Indicator**: Shows the battery level of the pet tracker device.
- **Speaker Button**: Triggers a buzzer on the device to help locate your pet.
- **Mode Selection**: Toggle between **Normal Mode** and **Search Mode**.

### History Screen
- View historical GPS data of your pet's movements on the map.

---

## Code Structure 🧩

- **`main.dart`**: Entry point of the app. Initializes Supabase and sets up the app state.
- **`MyAppState`**: Manages the app's state, including GPS data, battery levels, and device commands.
- **`MyHomePage`**: Main screen with navigation rail for switching between Home and History.
- **`MainPage`**: Displays the map, battery level, and speaker controls.
- **`HistoryPage`**: Shows historical GPS data on the map.
- **`BatteryIndicator`**: A widget to display the battery level.
- **`ModeSelectionWidget`**: Allows users to switch between Normal and Search modes.

---

## Dependencies 📦

The app uses the following Flutter packages:

- **`flutter_map`**: For displaying interactive maps.
- **`supabase_flutter`**: For backend integration.
- **`geolocator`**: For fetching the user's current location.
- **`latlong2`**: For handling latitude and longitude coordinates.
- **`intl`**: For formatting dates and times.

---

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/lora-pet-tracker.git
   cd lora-pet-tracker
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Set up Supabase**:
   - Replace the `url` and `anonKey` in the `main.dart` file with your Supabase project credentials.
   - Ensure your Supabase database has the following tables:
     - `device_status`: Stores GPS data, battery levels, and timestamps.
     - `device_commands`: Stores commands sent to the device (e.g., buzzer, mode).

4. **Run the app**:
   ```bash
   flutter run
   ```

---


[![Build Status](https://github.com/osm-search/Nominatim/workflows/CI%20Tests/badge.svg)](https://github.com/osm-search/Nominatim/actions?query=workflow%3A%22CI+Tests%22)

Nominatim
=========

Nominatim (from the Latin, 'by name') is a tool to search OpenStreetMap data
by name and address (geocoding) and to generate synthetic addresses of
OSM points (reverse geocoding). An instance with up-to-date data can be found
at https://nominatim.openstreetmap.org. Nominatim is also used as one of the
sources for the Search box on the OpenStreetMap home page.

Documentation
=============

The documentation of the latest development version is in the
`docs/` subdirectory. A HTML version can be found at
https://nominatim.org/release-docs/develop/ .

Installation
============

The latest stable release can be downloaded from https://nominatim.org.
There you can also find [installation instructions for the release](https://nominatim.org/release-docs/latest/admin/Installation), as well as an extensive [Troubleshooting/FAQ section](https://nominatim.org/release-docs/latest/admin/Faq/).

[Detailed installation instructions for current master](https://nominatim.org/release-docs/develop/admin/Installation)
can be found at nominatim.org as well.

A quick summary of the necessary steps:

1. Create a Python virtualenv and install the packages:

        python3 -m venv nominatim-venv
        ./nominatim-venv/bin/pip install packaging/nominatim-{api,db}

2. Create a project directory, get OSM data and import:

        mkdir nominatim-project
        cd nominatim-project
        ../nominatim-venv/bin/nominatim import --osm-file <your planet file>
        % alternative command with logging: ../nominatim-venv/bin/nominatim import --osm-file <your planet file> 2>&1 | tee setup.log -->


3. Start the webserver:

        ./nominatim-venv/bin/pip install uvicorn falcon
        ../nominatim-venv/bin/nominatim serve


License
=======

The Python source code is available under a GPL license version 3 or later.
The Lua configuration files for osm2pgsql are released under the
Apache License, Version 2.0. All other files are under a GPLv2 license.


Contributing
============

Contributions, bug reports and pull requests are welcome. When reporting a
bug, please use one of the
[issue templates](https://github.com/osm-search/Nominatim/issues/new/choose)
and make sure to provide all the information requested. If you are not
sure if you have really found a bug, please ask for help in the forums
first (see 'Questions' below).

For details on contributing, have a look at the
[contribution guide](CONTRIBUTING.md).


Questions and help
==================

If you have questions about search results and the OpenStreetMap data
used in the search, use the [OSM Forum](https://community.openstreetmap.org/).

For questions, community help and discussions around the software and
your own installation of Nominatim, use the
[Github discussions forum](https://github.com/osm-search/Nominatim/discussions).

