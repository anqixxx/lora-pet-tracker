import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
  print("Firebase Initialized");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Find Your Cat',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 229, 156, 150)),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  final CollectionReference _gpsDataRef = FirebaseFirestore.instance.collection('gps_data');

  StreamSubscription<QuerySnapshot>? _gpsDataSubscription;
  List<Map<String, dynamic>> gpsDataList = [];
  List<Map<String, dynamic>> commands = [];

  MyAppState() {
    _startListeningForData();
  }

  void _startListeningForData() {
    print("Listening for GPS data... NEW");
    _gpsDataSubscription = _gpsDataRef.snapshots().listen((querySnapshot) {
      gpsDataList = querySnapshot.docs
          .map((doc) => {
            'lat': doc['lat'],
            'long': doc['long'],
            'time': doc['time']
          })
          .toList();
      print("waiting");
      gpsDataList.forEach((data) {
        print("New GPS Data: Latitude = ${data['lat']}, Longitude = ${data['long']}");
      });

      notifyListeners();
    });
  }

  Map<String, dynamic>? get latestGpsData {
      if (gpsDataList.isNotEmpty) {
        return gpsDataList.last;
      }
      return null;
    }

  @override
  void dispose() {
    _gpsDataSubscription?.cancel();
    super.dispose();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = MainPage();
        break;
      case 1:
        page = HistoryPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 600,
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history),
                      label: Text('History'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    print('Selected: $value');
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: page,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _start = 0; // Variable to keep track of the countdown
  bool _isRunning = false; // Variable to check if countdown is running
  Timer? _timer; // Timer for countdown

  // Firestore reference (you can change the collection and document paths as needed)
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  void startCountdown() {
    setState(() {
      _start = 30; // Set countdown to 30 seconds
      _isRunning = true; // Mark countdown as running
    });
    
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_start > 0) {
        setState(() {
          _start--; // Decrement countdown
        });
      } else {
        timer.cancel(); // Cancel timer when countdown reaches zero
        stopSpeaker(); // Stop the speaker when countdown reaches 0
        }
    });
  }

  // Function to send a command to Firestore
  void startSpeaker() async {
    try {
      await _firestore.collection('commands').add({
        'timestamp': FieldValue.serverTimestamp(),
        'command': 'start_speaker',
      });
      print("Speaker command sent to Firestore");
    } catch (e) {
      print("Error sending speaker command to Firestore: $e");
    }
  }

  void stopSpeaker() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _start = 0; // Reset countdown
    });

    // Send 'stop_speaker' command to Firestore
    FirebaseFirestore.instance.collection('speakerCommands').add({
      'timestamp': FieldValue.serverTimestamp(),
      'command': 'stop_speaker',
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Lora App"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Map Section
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(49.2827, -123.1207), // Center map on Vancouver
                    initialZoom: 13.0,
                  ),
                  children: [
                    map(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            // Mode Selection Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Normal Mode functionality here
                  },
                  child: Text("Normal Mode"),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    // Search Mode functionality here
                  },
                  child: Text("Search Mode"),
                ),
              ],
            ),
            SizedBox(height: 20),
            // Battery and Last Updated Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BatteryIndicator(batteryLevel: 0.05), // Replace with actual battery level variable
                Column(
                  children: [
                    Text("Last Checked"),
                    Text("10:09"), // Replace with dynamic timestamp
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            // Speaker and Timer Section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    print("Speaker button pressed");
                    if (_isRunning) {
                    // Reset countdown if already running
                      setState(() {
                      _start = 30; // Reset countdown
                    });
                    } else {
                      startCountdown(); // Start countdown if not running
                    }
                    // Send Firestore command for the speaker
                    startSpeaker();                  
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    minimumSize: Size(100, 50),
                    textStyle: TextStyle(fontSize: 16)
                  ),

                  child: Text("Speaker"),
                ),
                SizedBox(width: 20),
                if (_isRunning)
                ...[
                  // Countdown
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '$_start', // Display countdown value
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  SizedBox(width: 10),
                  
                  // Square Stop button
                  Container(
                    width: 50, // Set width for the square
                    height: 50, // Set height for the square
                    child: IconButton(
                      onPressed: stopSpeaker, // Stop the speaker when pressed
                      icon: Icon(Icons.stop, color: Colors.grey), // "X" icon in white
                      iconSize: 30, // Icon size
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: historyMap(),
    );
  }
}

class BatteryIndicator extends StatelessWidget {
  final double batteryLevel; // Battery level as a decimal, e.g., 0.75 for 75%.

  BatteryIndicator({required this.batteryLevel});

  @override
  Widget build(BuildContext context) {
    IconData batteryIcon;

    if (batteryLevel > 0.8) {
      batteryIcon = Icons.battery_full;
    } else if (batteryLevel > 0.4) {
      batteryIcon = Icons.battery_6_bar;
    } else if (batteryLevel > 0.2) {
      batteryIcon = Icons.battery_3_bar;
    } else {
      batteryIcon = Icons.battery_0_bar;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40, // Width of the battery indicator
          child: LinearProgressIndicator(
            value: batteryLevel,
            backgroundColor: Colors.grey[300],
            color: batteryLevel > 0.2 ? Colors.green : Colors.red,
          ),
        ),
        SizedBox(height: 5), // Add vertical space
        // Transform.rotate(
        //   angle: 3.14159 / 2, // Rotate by 90 degrees (PI/2 radians)
        //   child: Icon(
        //     batteryIcon,
        //     color: batteryLevel > 0.2 ? Colors.green : Colors.red,
        //   ),
        // ),
        // SizedBox(height: 5), // Add vertical space between elements
        Text("Battery Level: ${(batteryLevel * 100).toInt()}%"),
      ],
    );
  }
}



Widget historyMap() {
  return FutureBuilder<Position>(
    future: _getCurrentLocation(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        // Show a loading indicator while waiting for the location.
        return Center(child: CircularProgressIndicator());
      } else if (snapshot.hasError) {
        // Show an error message if location cannot be accessed.
        return Center(child: Text('Error: ${snapshot.error}'));
      } else {
        // Use the current location for the initial center of the map.
        final position = snapshot.data;
        final initialCenter = LatLng(position!.latitude, position.longitude);

        return Consumer<MyAppState>(
          builder: (context, appState, child) {
            final gpsDataList = appState.gpsDataList; // Get firebase GPS data

            List<Marker> markers = [
              // Add a marker for the current location, making it red
              Marker(
                width: 80.0,
                height: 80.0,
                point: initialCenter,
                alignment: Alignment.center,
                child: Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
              // Add markers for each GPS data point from Firebase, making them black
              if (gpsDataList.isNotEmpty) 
                ...gpsDataList.map((data) {
                  final latitude = data['lat'] as double;
                  final longitude = data['long'] as double;
                  final point = LatLng(latitude, longitude);

                  return Marker(
                    width: 80.0,
                    height: 80.0,
                    point: point,
                    alignment: Alignment.center,
                    child: Icon(Icons.location_on, color: Colors.black, size: 40),
                  );
                }).toList(),  // Convert map result to List<Marker>
            ];

            return FlutterMap(
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 13, // Set your preferred initial zoom level.
                interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.doubleTapZoom),
              ),
              children: [
                openStreetMapTileLayer,
                MarkerLayer(
                  markers: markers,
                ),
              ],
            );
          },
        );
      }
    },
  );
}

Widget map() {
  return FutureBuilder<Position>(
    future: _getCurrentLocation(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        // Show a loading indicator while waiting for the location.
        return Center(child: CircularProgressIndicator());
      } else if (snapshot.hasError) {
        // Show an error message if location cannot be accessed.
        return Center(child: Text('Error: ${snapshot.error}'));
      } else {
        // Use the current location for the initial center of the map.
        final position = snapshot.data;
        final initialCenter = LatLng(position!.latitude, position.longitude);

        return Consumer<MyAppState>(
          builder: (context, appState, child) {
            final latestPosition = appState.latestGpsData; // Get firebase GPS data

            // Initialize the list of markers with the current location marker.
            List<Marker> markers = [
              Marker(
                width: 80.0,
                height: 80.0,
                point: initialCenter,
                alignment: Alignment.center,
                child: Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            ];

            // Add a black marker for the latest GPS data if it exists.
            if (latestPosition != null && latestPosition.isNotEmpty) {
              final latitude = latestPosition['lat'] as double;
              final longitude = latestPosition['long'] as double;
              final point = LatLng(latitude, longitude);

              markers.add(
                Marker(
                  width: 80.0,
                  height: 80.0,
                  point: point,
                  alignment: Alignment.center,
                  child: Icon(Icons.location_on, color: Colors.black, size: 40),
                ),
              );
            }

            return FlutterMap(
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 13, // Set your preferred initial zoom level.
                interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.doubleTapZoom),
              ),
              children: [
                openStreetMapTileLayer,
                MarkerLayer(
                  markers: markers,
                ),
              ],
            );
          },
        );
      }
    },
  );
}


TileLayer get openStreetMapTileLayer => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'dev.fleaflet.flutter_map.lora',
);

Future<Position> _getCurrentLocation() async {
  // Request permission to access the device's location.
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled, so return a default position.
    return Future.error('Location services are disabled.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied.');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are permanently denied, so return a default position.
    return Future.error('Location permissions are permanently denied.');
  }

  // When permission is granted, get the current position.
  return await Geolocator.getCurrentPosition();
}
