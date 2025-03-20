import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

// Setup
final Color defaultColor = Color.fromARGB(255, 229, 156, 150);
final int deviceId = 0; // 0 for actual, 1 for test, 2 for experimental

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Flutter Initialized');

  await Supabase.initialize(
    url: 'https://mgrgaxqqtvqttxvulbnk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ncmdheHFxdHZxdHR4dnVsYm5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzc0MDUyMDgsImV4cCI6MjA1Mjk4MTIwOH0.A3VybPyJGZ3Bm2rfe1BMZLM_51eVKFmW0uEGSi6qZhI',
  );
  
  runApp(MyApp());
  print("Supabase Initialized");
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
        primaryColor: defaultColor,
        colorScheme: ColorScheme.fromSeed(seedColor: defaultColor),
      ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  StreamSubscription? _nodeDataSubscription;
  List<Map<String, dynamic>> gpsDataList = [];
  List<Map<String, dynamic>> batteryLevelList = [];
  List<Map<String, dynamic>> commands = [];
  // Tuple of batteryLevel
  final ValueNotifier<Map<String, dynamic>?> latestGpsNotifier = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> latestBatteryNotifier = ValueNotifier(null);

  MyAppState() {
    print("MyAppState initialized!");  // Debugging
    _startListeningForData();
  }

  void _startListeningForData() {
    _nodeDataSubscription = supabase
        .from('device_status')
        .stream(primaryKey: ['id'])
        .listen((data) {
      print("Listening to Supabase stream...");

      // Filter out entries where any GPS value is null
      gpsDataList = data
          .where((entry) =>
              entry['gps_latitude'] != null &&
              entry['gps_longitude'] != null &&
              entry['timestamp'] != null)
          .map((entry) => {
                'lat': entry['gps_latitude'],
                'long': entry['gps_longitude'],
                'time': entry['timestamp']
              })
          .toList();
      // Filter out entries where battery_level or timestamp is null
      batteryLevelList = data
          .where((entry) => entry['battery_level'] != null && entry['timestamp'] != null)
          .map((entry) => {
                'battery': entry['battery_level'],
                'time': entry['timestamp']
              })
          .toList();
      print("Updated battery level list: $batteryLevelList");  // Debugging line

      final newLatestGpsData = gpsDataList.isNotEmpty ? gpsDataList.last : null;
      if (newLatestGpsData != latestGpsNotifier.value) {
        latestGpsNotifier.value = newLatestGpsData;
      }

      // Update battery notifier when new data is available
      final newLatestBatteryData = batteryLevelList.isNotEmpty ? batteryLevelList.last : null;
      if (newLatestBatteryData != latestBatteryNotifier.value) {
        latestBatteryNotifier.value = newLatestBatteryData;
      }

      notifyListeners();
    });
  }

  Map<String, dynamic>? get latestGpsData {
      if (gpsDataList.isNotEmpty) {
        print("Latest GPS Data: Latitude = ${gpsDataList.last['lat']}, Longitude = ${gpsDataList.last['long']}, Time = ${gpsDataList.last['time']}");
        return gpsDataList.last;
      }
      return null;
    }

  Map<String, dynamic>? get latestBatteryLevel {
    if (batteryLevelList.isNotEmpty) {
      print("Last Updated Battery Level = ${batteryLevelList.last['battery']}, Time = ${batteryLevelList.last['time']}");
      return batteryLevelList.last;
    }
    return null;
  }

  void requestBattery() async {
    print("Requesting Battery Update");

    try {
      final response = await supabase.from('device_commands').insert({
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'battery': true,
          'status': false,
          'device_id': deviceId,      
        });
      print(response.error);
    } catch (e) {
      print("Unexpected error sending battery request: $e");
    }
  }

    // Function to select mode
  void selectMode(String mode) async {
    print('mode : ' + mode);
    try {
      final response = await supabase.from('device_commands').insert({
        'timestamp': DateTime.now().toUtc().toIso8601String(), 
        'mode': mode,
      });
      if (response.error == null){
        print("Mode command sent to Supabase");
      } else{
        print("Error sending command to Supabase: ${response.error.message}");
      }

    } catch (e) {
      print("Unexpected error sending mode command: $e");
    }
  }

  void requestGPS() async {
    print("Requesting GPS Update");

    try {
      final response = await supabase.from('device_commands').insert({
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'gps': true,
          'status': false,
          'device_id': deviceId,      
        });
      print(response.error);
    } catch (e) {
      print("Unexpected error sending gps request: $e");
    }
  }

  @override
  void dispose() {
    latestGpsNotifier.dispose();
    latestBatteryNotifier.dispose();
    _nodeDataSubscription?.cancel();
    super.dispose();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  bool showNavRail = false; 

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = MainPage();
      case 1:
        page = HistoryPage();
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

  return LayoutBuilder(
  builder: (context, constraints) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              if (showNavRail)
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
          
          Positioned(
            top: 10,
            right: 10,
            child: SafeArea(
              child: IconButton(
                onPressed: () {
                  setState(() {
                    showNavRail = !showNavRail;
                  });
                },
                icon: Icon(
                  showNavRail ? Icons.menu_open : Icons.menu,
                  color: Theme.of(context).colorScheme.primary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  elevation: 4,
                ),
              ),
            ),
          ),
        ],
      ),
      );
    },
  );
  }
}

class _TopRightFloatingActionButtonLocation extends FloatingActionButtonLocation {
  const _TopRightFloatingActionButtonLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    return Offset(
      scaffoldGeometry.scaffoldSize.width - scaffoldGeometry.floatingActionButtonSize.width - 16.0,
      16.0 // Top margin
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  final supabase = Supabase.instance.client;

  void startSpeaker() async {
    try {
      final response = await supabase.from('device_commands').insert({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'buzzer': true,
        'status': false,
        'device_id': deviceId,
      });

      if (response.error == null) {
        print("Speaker command sent to Supabase");
      } else {
        print("Error sending command to Supabase: ${response.error.message}");
      }
    } catch (e) {
      print("Unexpected error sending speaker command: $e");
    }
  }

  void stopSpeaker() async {
    try {
      final response = await supabase.from('device_commands').insert({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'buzzer': false,
        'status': false,
        'device_id': deviceId,
      });

      if (response.error == null) {
        print("Stop speaker command sent to Supabase");
      } else {
        print("Error sending stop command to Supabase: ${response.error.message}");
      }
    } catch (e) {
      print("Unexpected error sending stop speaker command: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "🐈 🐈 🐈",
          style: TextStyle(
            fontFamily: 'font',
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Map Section
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MapWidget(), // Use the new MapWidget here
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: () {
                        final appState = Provider.of<MyAppState>(context, listen: false);
                        appState.requestGPS();
                      },
                      mini: true,
                      child: Icon(Icons.refresh),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Mode Selection Buttons
            ModeSelectionWidget(),

            SizedBox(height: 20),

            // Battery Selection            
            battery(context),

            SizedBox(height: 20),
            
            // Speaker and Timer Section
            SpeakerTimerWidget(
              onStartSpeaker: startSpeaker,
              onStopSpeaker: stopSpeaker,
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
          width: 110, // Width of the battery indicator
          height: 10,
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

class ModeSelectionWidget extends StatefulWidget {
  @override
  ModeSelectionWidgetState createState() => ModeSelectionWidgetState();
}

class ModeSelectionWidgetState extends State<ModeSelectionWidget> {
  bool normalmode = true; // Default to Normal Mode

  void selectMode(String mode) {
    final appState = Provider.of<MyAppState>(context, listen: false);
    appState.selectMode(mode);
  }

  void requestGPS() {
    final appState = Provider.of<MyAppState>(context, listen: false);
    appState.requestGPS();
  } 

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: normalmode
              ? null // Disable button when Normal Mode is selected (normalmode is true)
              : () {
                  setState(() {
                    normalmode = true; // Switch to Normal Mode
                  });
                  print("Normal Mode on");
                print("normalmode is: $normalmode");
                selectMode('n');

                  // Normal Mode functionality here
                },
          style: ElevatedButton.styleFrom(
            // backgroundColor: normalmode ? null: Colors.grey[300], // Set color
            // foregroundColor: normalmode ? null: Colors.grey[500], // Set color
            backgroundColor: normalmode ? null: null, // Set color
            foregroundColor: normalmode ? null: null, // Set color            
          ),
          child: Text("Normal Mode"),
        ),
        SizedBox(width: 20),
        ElevatedButton(
          onPressed: !normalmode
              ? null // Disable button when Search Mode is selected (normalmode is false)
              : () {
                  setState(() {
                    normalmode = false; // Switch to Search Mode
                  });
                  print('Search mode on');
                selectMode('s');
                  // Search Mode functionality here
                  
                },
          style: ElevatedButton.styleFrom(
            // backgroundColor: !normalmode ?  null : Colors.grey[300], // Set color
            // foregroundColor: !normalmode ?  null : Colors.grey[500], // Set color
            backgroundColor: !normalmode ?  null : null, // Set color
            foregroundColor: !normalmode ?  null : null, // Set color
          ),
          child: Text("Search Mode"),
        ),
      ],
    );
  }

}

Stream<Position> _getLocationStream() {
  return Geolocator.getPositionStream(
    locationSettings: LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );
}

Widget historyMap() {
  return StreamBuilder<Position>(
    stream: _getLocationStream(), // Stream to get real-time location updates
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator()); // Loading indicator
      } else if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}')); // Error handling
      } else if (!snapshot.hasData || snapshot.data == null) {
        return Center(child: Text('Location data is unavailable'));
      } else {
        final position = snapshot.data!;
        final initialCenter = LatLng(position.latitude, position.longitude);

        return Consumer<MyAppState>(
          builder: (context, appState, child) {
              final gpsDataList = appState.gpsDataList;
              // Filter out any GPS data that has null values for latitude or longitude
              final validGpsDataList = gpsDataList.where((data) {
              final latitude = data['lat'] as double?;
              final longitude = data['long'] as double?;
              return latitude != null && longitude != null;
            }).toList();
            final markers = _buildMarkers(initialCenter, validGpsDataList);

            return FlutterMap(
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 13, // Set your preferred initial zoom level
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

List<Marker> _buildMarkers(LatLng initialCenter, List<Map<String, dynamic>> gpsDataList) {
  List<Marker> markers = [
    // Marker for the current location (red)
    Marker(
      width: 80.0,
      height: 80.0,
      point: initialCenter,
      alignment: Alignment.center,
      child: Icon(Icons.location_on, color: Colors.black, size: 30),
    ),
  ];

  // Add markers for each valid GPS data point (black)
  if (gpsDataList.isNotEmpty) {
    markers.addAll(gpsDataList.map((data) {
      final latitude = data['lat'] as double;
      final longitude = data['long'] as double;
      final point = LatLng(latitude, longitude);

      return Marker(
        width: 50.0,
        height: 50.0,
        point: point,
        alignment: Alignment.center,
        child: Icon(Icons.location_on, color: Colors.red, size: 30),
      );
    }).toList());
  }

  return markers;
}

class MapWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Position>(
      future: _getCurrentLocation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          final position = snapshot.data;
          final initialCenter = LatLng(position!.latitude, position.longitude);

          return ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: Provider.of<MyAppState>(context, listen: false).latestGpsNotifier,
            builder: (context, latestPosition, child) {
              List<Marker> markers = [
                Marker(
                  width: 80.0,
                  height: 80.0,
                  point: initialCenter,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () {
                      final snackBar = SnackBar(
                        content: Text(
                          'GPS Time ${DateFormat('hh:mm a MMM dd').format(DateTime.now())}',
                          textAlign: TextAlign.center,
                        ),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.only(top: 10, left: 20, right: 20),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    },
                    child: Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                ),
              ];

              if (latestPosition != null) {
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
                  initialZoom: 13,
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
}

Widget battery(BuildContext context) {
  return ValueListenableBuilder<Map<String, dynamic>?>(
    valueListenable: Provider.of<MyAppState>(context, listen: false).latestBatteryNotifier,
    builder: (context, latestBattery, child) {
      if (latestBattery != null && latestBattery.isNotEmpty) {
        final batteryPercent = latestBattery['battery'];
        final time = latestBattery['time'];
        DateTime formattedTime = DateTime.parse(time);
        String formattedDate = DateFormat('hh:mm a MMM dd').format(formattedTime);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            BatteryIndicator(batteryLevel: batteryPercent / 100),
            SizedBox(width: 30),
            Column(
              children: [
                Text("Last Checked"),
                Text(formattedDate),
              ],
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                Provider.of<MyAppState>(context, listen: false).requestBattery();
              },
            ),
          ],
        );
      } else {
        return Text("No battery data available");
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

class SpeakerTimerWidget extends StatefulWidget {
  final void Function() onStartSpeaker;
  final void Function() onStopSpeaker;

  const SpeakerTimerWidget({
    required this.onStartSpeaker,
    required this.onStopSpeaker,
    Key? key,
  }) : super(key: key);

  @override
  _SpeakerTimerWidgetState createState() => _SpeakerTimerWidgetState();
}

class _SpeakerTimerWidgetState extends State<SpeakerTimerWidget> {
  int _start = 0; // Countdown timer value
  bool _isRunning = false; // Whether the timer is running
  Timer? _timer; // Timer instance

  void startCountdown() {
    setState(() {
      _start = 30; // Set countdown to 30 seconds
      _isRunning = true; // Mark timer as running
    });

    widget.onStartSpeaker(); // Trigger the start speaker callback

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_start > 0) {
        setState(() {
          _start--; // Decrement countdown
        });
      } else {
        stopCountdown(); // Stop the timer when it reaches 0
      }
    });
  }

  void stopCountdown() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _start = 0; // Reset countdown
    });

    widget.onStopSpeaker(); // Trigger the stop speaker callback
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () {
            if (_isRunning) {
              setState(() {
                _start = 30; // Reset countdown if already running
              });
            } else {
              startCountdown(); // Start countdown if not running
            }
          },
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.red,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            minimumSize: Size(100, 50),
            textStyle: TextStyle(fontSize: 16),
          ),
          child: Text("Speaker"),
        ),
        SizedBox(width: 20),
        if (_isRunning) ...[
          // Countdown display
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '$_start',
              style: TextStyle(fontSize: 20),
            ),
          ),
          SizedBox(width: 10),
          // Stop button
          SizedBox(
            width: 50,
            height: 50,
            child: IconButton(
              onPressed: stopCountdown,
              icon: Icon(Icons.stop, color: Colors.grey),
              iconSize: 30,
            ),
          ),
        ],
      ],
    );
  }
}
