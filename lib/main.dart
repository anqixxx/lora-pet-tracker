import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Lora App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  final DatabaseReference _gpsDataRef = FirebaseDatabase.instance.ref('gpsData');
  final DatabaseReference _commandsRef = FirebaseDatabase.instance.ref('commands');

  StreamSubscription<DatabaseEvent>? _gpsDataSubscription;
  StreamSubscription<DatabaseEvent>? _commandSubscription;
  List<Map<String, dynamic>> gpsDataList = [];
  List<Map<String, dynamic>> commands = [];

  MyAppState() {
    _startListeningForGPSData();
    _startListeningForCommands();
  }

  void _startListeningForGPSData() {
    _gpsDataSubscription = _gpsDataRef.limitToLast(100).onValue.listen((event) {
      if (event.snapshot.value != null) {
        gpsDataList = (event.snapshot.value as Map).values
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        notifyListeners();
      }
    });
  }

  void _startListeningForCommands() {
    _commandSubscription = _commandsRef.onChildAdded.listen((event) {
      final newCommand = Map<String, dynamic>.from(event.snapshot.value as Map);
      commands.add(newCommand);
      notifyListeners();
    });
  }

  Future<void> sendGPSData(double latitude, double longitude) async {
    await _gpsDataRef.push().set({
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> sendCommand(String commandType, [Map<String, dynamic>? payload]) async {
    await _commandsRef.push().set({
      'commandType': commandType,
      'payload': payload,
    });
  }

  @override
  void dispose() {
    _gpsDataSubscription?.cancel();
    _commandSubscription?.cancel();
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
                      label: Text('Favorites'),
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

  void startCountdown() {
    setState(() {
      _start = 10; // Set countdown to 10 seconds
      _isRunning = true; // Mark countdown as running
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_start > 0) {
        setState(() {
          _start--; // Decrement countdown
        });
      } else {
        timer.cancel(); // Cancel timer when countdown reaches zero
        setState(() {
          _isRunning = false; // Mark countdown as not running
          _start = 0; // Reset start to 0 for display purposes
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  if (_isRunning) {
                    // Reset countdown if already running
                    setState(() {
                      _start = 30; // Reset countdown
                    });
                  } else {
                    startCountdown(); // Start countdown if not running
                  }
                },
                child: Text('Speaker'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  minimumSize: Size(100, 50),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(width: 10), // Space between button and countdown
              if (_isRunning) // Show countdown only if running
                Container(
                  width: 40, // Set a width for the countdown display
                  alignment: Alignment.center,
                  child: Text(
                    '$_start',
                    style: TextStyle(fontSize: 20), // Larger font for countdown
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: map(),
    );
  }
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

        return FlutterMap(
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 13, // Set your preferred initial zoom level.
            interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.doubleTapZoom),
          ),
          children: [
            openStreetMapTileLayer,
            MarkerLayer(
              markers: [
                Marker(
                  width: 80.0,
                  height: 80.0,
                  point: initialCenter,
                  alignment: Alignment.center,
                  child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                ),
              ],
            ),
          ],
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
