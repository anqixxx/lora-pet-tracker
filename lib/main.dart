import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';


import 'package:supabase_flutter/supabase_flutter.dart';

// Setup
final Color defaultColor = Color(0xFFFFDBD7); // Light pink color
const int deviceId = 0; // 0 for actual, 1 for test, 2 for experimental
final ValueNotifier<bool> isSleepMode = ValueNotifier(false);
final ValueNotifier<DateTime?> lastSleepTime = ValueNotifier(null);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Flutter Initialized');

  try {
    await Supabase.initialize(
      url: 'https://mgrgaxqqtvqttxvulbnk.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ncmdheHFxdHZxdHR4dnVsYm5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzc0MDUyMDgsImV4cCI6MjA1Mjk4MTIwOH0.A3VybPyJGZ3Bm2rfe1BMZLM_51eVKFmW0uEGSi6qZhI',
    );
    print("Supabase Initialized");
    runApp(MyApp());
  } catch (e) {
    print("Failed to initialize Supabase: $e");
    runApp(DatabaseErrorApp()); // error app instead of just an empty container
    return;
  }

}

class DatabaseErrorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Database Connection Error',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Unable to connect to the database. Please check your internet connection and Supabase credentials and try again later.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Attempt to restart the app
                  main();
                },
                child: Text('Retry Connection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                'time': convertToLocalTime(entry['timestamp'])
              })
          .toList();
      // Filter out entries where battery_level or timestamp is null
      batteryLevelList = data
          .where((entry) => entry['battery_level'] != null && entry['timestamp'] != null)
          .map((entry) => {
                'battery': entry['battery_level'],
                'time': convertToLocalTime(entry['timestamp'])
              })
          .toList();

      final newLatestGpsData = gpsDataList.isNotEmpty ? gpsDataList.last : null;
      if (newLatestGpsData != latestGpsNotifier.value) {
        latestGpsNotifier.value = newLatestGpsData;
      }

      // Update battery notifier when new data is available
      final newLatestBatteryData = batteryLevelList.isNotEmpty ? batteryLevelList.last : null;
      if (newLatestBatteryData != latestBatteryNotifier.value) {
        latestBatteryNotifier.value = newLatestBatteryData;
      }

      print("Updated GPS Value: $newLatestGpsData");  // Debugging line

      print("Updated Battery Level Value: $newLatestBatteryData");  // Debugging line

      // Find latest sleep mode time and latest non sleep mode time. If the former is most recent, we are in sleep mode and no GPS data is sent
      final sleepEntries = data.where((entry) => entry['sleep'] != null && entry['timestamp'] != null);
      
      if (sleepEntries.isNotEmpty) {
        final latestSleepEntry = sleepEntries.reduce((a, b) => DateTime.parse(a['timestamp']).isAfter(DateTime.parse(b['timestamp'])) ? a : b);

        isSleepMode.value = latestSleepEntry['sleep'];
      
        print("Sleep Mode Status: ${isSleepMode.value}");

        if (isSleepMode.value) {
          final sleepTimestamp = convertToLocalTime(latestSleepEntry['timestamp']);
          lastSleepTime.value = sleepTimestamp;
        }
      }

      notifyListeners();
    });
  }

  Map<String, dynamic>? get latestGpsData {
      if (gpsDataList.isNotEmpty) {
        print("Latest GPS Data: Latitude = ${gpsDataList.last['lat']}, Longitude = ${gpsDataList.last['long']}, Time = $gpsDataList.last['time']");
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
    print('Mode : $mode');
    try {
      final response = await supabase.from('device_commands').insert({
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
      body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
        SizedBox(height:15),

        // Picture Section
        LayoutBuilder(
          builder: (context, constraints) {
            final catWidth = constraints.maxWidth * 0.12; 
            return Container(
              width: catWidth,
              height: 50, 
              decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: AssetImage('assets/images/cat.png'),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {
              print('Error loading image: $exception');
            },
          ),
              ),
            );
          },
        ),

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

class HistoryPage extends StatefulWidget {
  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  double _sliderValue = 0;

  DateTime get timeFilter {
    final now = DateTime.now();
    if (_sliderValue == 0) return now.subtract(Duration(hours: 1));
    if (_sliderValue == 1) return now.subtract(Duration(days: 1));
    if (_sliderValue == 2) return now.subtract(Duration(days: 7));
    if (_sliderValue == 3) return now.subtract(Duration(days: 30));
    return DateTime.fromMillisecondsSinceEpoch(0); // All time (Unix epoch)
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fullscreen Map
          Positioned.fill(
            child: historyMap(timeFilter),
          ),

          // Slider overlay at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 30,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: defaultColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: defaultColor, blurRadius: 6),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    inactiveColor: Colors.white,
                    value: _sliderValue,
                    min: 0,
                    max: 4,
                    divisions: 4,
                    label: ["Last Hour", "Last Day", "Last Week", "Last Month", "All"][_sliderValue.toInt()],
                    onChanged: (value) {
                      setState(() {
                        _sliderValue = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

Widget historyMap(DateTime timeFilter) {
  return StreamBuilder<Position>(
    stream: _getLocationStream(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      } else if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      } else if (!snapshot.hasData || snapshot.data == null) {
        return Center(child: Text('Location data is unavailable'));
      } else {
        final position = snapshot.data!;
        final initialCenter = LatLng(position.latitude, position.longitude);

        return Consumer<MyAppState>(
          builder: (context, appState, child) {
          final filteredData = appState.gpsDataList.where((data) {
            final time = data['time'] as DateTime;
            return time.isAfter(timeFilter);
          }).toList();


            final markers = _buildMarkers(initialCenter, filteredData, context);

            return FlutterMap(
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 13,
                interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.doubleTapZoom),
              ),
              children: [
                openStreetMapTileLayer,
                MarkerLayer(markers: markers),
              ],
            );
          },
        );
      }
    },
  );
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
    return ValueListenableBuilder<bool>(
      valueListenable: isSleepMode,
      builder: (context, inSleepMode, child) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: inSleepMode 
                      ? null // Disable when in sleep mode
                      : (normalmode ? null : () {
                          setState(() {
                            normalmode = true;
                          });
                          print("Normal Mode on");
                          print("normalmode is: $normalmode");
                          selectMode('n');
                        }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: inSleepMode ? Colors.grey[300] : null,
                    foregroundColor: inSleepMode ? Colors.grey[500] : null,
                  ),
                  child: Text("Normal Mode"),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: inSleepMode
                      ? null // Disable when in sleep mode
                      : (!normalmode ? null : () {
                          setState(() {
                            normalmode = false;
                          });
                          print('Search mode on');
                          selectMode('s');
                        }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: inSleepMode ? Colors.grey[300] : null,
                    foregroundColor: inSleepMode ? Colors.grey[500] : null,
                  ),
                  child: Text("Search Mode"),
                ),
              ],
            ),
            if (inSleepMode)
              Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: defaultColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ValueListenableBuilder<DateTime?>(
                  valueListenable: lastSleepTime,
                  builder: (context, time, _) {
                    final sleepTimeText = time != null 
                      ? DateFormat('hh:mm a MMM dd').format(time)
                      : "Unknown time";
                    
                    return Column(
                      children: [
                        Text(
                          "Sleep Mode Active",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          "Sleep Detected From $sleepTimeText",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      }
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

List<Marker> _buildMarkers(LatLng initialCenter, List<Map<String, dynamic>> gpsDataList, BuildContext context) {
  List<Marker> markers = [
    // Marker for the current location (red)
    Marker(
      width: 80.0,
      height: 80.0,
      point: initialCenter,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          final formattedDate = DateFormat('hh:mm a MMM dd yyyy').format(DateTime.now());
          final snackBar = SnackBar(
            content: Text(
              'Your Time: $formattedDate',
              textAlign: TextAlign.center,
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(top: 10, left: 20, right: 20),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        },
        child: Icon(Icons.location_on, color: Colors.black, size: 40),
      ),
    ),
  ];

  // Add markers for each valid GPS data point (black)
  if (gpsDataList.isNotEmpty) {
    markers.addAll(gpsDataList.map((data) {
      final latitude = data['lat'] as double;
      final longitude = data['long'] as double;
      final point = LatLng(latitude, longitude);
      final time = data['time'];
      String formattedDate = DateFormat('hh:mm a MMM dd yyyy').format(time);

      return Marker(
        width: 50.0,
        height: 50.0,
        point: point,
        alignment: Alignment.center,
        child: GestureDetector(
                onTap: () {
                  final snackBar = SnackBar(
                    content: Text(
                      'GPS Time: $formattedDate',
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
    );
    }).toList());
  }

  return markers;
}

class MapWidget extends StatefulWidget {
  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController(); // Initialize the MapController
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: Provider.of<MyAppState>(context, listen: false).latestGpsNotifier,
      builder: (context, latestPosition, child) {
        return FutureBuilder<Position>(
          future: _getCurrentLocation(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              // Use the latest GPS position if available, otherwise fallback to the current location
              final initialCenter = latestPosition != null
                  ? LatLng(latestPosition['lat'], latestPosition['long'])
                  : LatLng(snapshot.data!.latitude, snapshot.data!.longitude);

              List<Marker> markers = [
                Marker(
                  width: 80.0,
                  height: 80.0,
                  point: LatLng(snapshot.data!.latitude, snapshot.data!.longitude),
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () {
                      final snackBar = SnackBar(
                        content: Text(
                          'Your Time: ${DateFormat('hh:mm a MMM dd yyyy').format(DateTime.now())}',
                          textAlign: TextAlign.center,
                        ),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.only(top: 10, left: 20, right: 20),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    },
                    child: Icon(Icons.location_on, color: Colors.black, size: 40),
                  ),
                ),
              ];

              // Add a marker for the latest GPS position if it exists
              if (latestPosition != null) {
                final time = latestPosition['time'];
                String formattedDate = DateFormat('hh:mm a MMM dd yyyy').format(time);

                markers.add(
                  Marker(
                    width: 80.0,
                    height: 80.0,
                    point: LatLng(latestPosition['lat'], latestPosition['long']),
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () {
                        final snackBar = SnackBar(
                          content: Text(
                            'Latest GPS Time: $formattedDate',
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
                );
              }

              return FlutterMap(
                mapController: _mapController, // Pass the MapController here
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
            }
          },
        );
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
        String formattedDate = DateFormat('hh:mm a MMM dd').format(time);

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

// Convert local time
DateTime convertToLocalTime(String utcTimeString) {
  final utcTime = DateTime.parse(utcTimeString);
  return utcTime.toLocal();
}

// Format the local time into a readable string
String formatLocalTime(String utcTimeString, {String format = 'hh:mm a MMM dd'}) {
  final localTime = convertToLocalTime(utcTimeString);
  return DateFormat(format).format(localTime);
}