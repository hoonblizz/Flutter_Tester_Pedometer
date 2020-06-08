import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tester_pedometer/background_task_view.dart';
import 'package:flutter_tester_pedometer/health_view.dart';
import 'package:flutter_tester_pedometer/pedometer_view.dart';
import 'package:flutter_tester_pedometer/util.dart';
import 'package:pedometer/pedometer.dart';
import 'package:health/health.dart';

import 'package:background_fetch/background_fetch.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const EVENTS_KEY = "fetch_events";

/* ***********************************************************************
    Local Notification Setup
  *************************************************************************/
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/* ***********************************************************************
    Background Task Setup
  *************************************************************************/
/// Android only: This "Headless Task" is run when app is terminated.
void backgroundFetchHeadlessTask(String taskId) async {
  print('[BackgroundFetch] Headless event received.');

  DateTime timestamp = DateTime.now();

  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Read fetch_events from SharedPreferences
  List<String> events = [];
  String json = prefs.getString(EVENTS_KEY);
  if (json != null) {
    events = jsonDecode(json).cast<String>();
  }
  // Add new event.
  events.insert(0, "$taskId@$timestamp [Headless]");
  // Persist fetch events in SharedPreferences
  prefs.setString(EVENTS_KEY, jsonEncode(events));

  BackgroundFetch.finish(taskId);

  if (taskId == 'flutter_background_fetch') {
    BackgroundFetch.scheduleTask(TaskConfig(
        taskId: "com.transistorsoft.pedometer",
        delay: 5000,
        periodic: false,
        forceAlarmManager: true,
        stopOnTerminate: false,
        enableHeadless: true));
  }
}

Future<void> main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  /* ***********************************************************************
    Local Notification Setup
  *************************************************************************/
  // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
  var initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
  var initializationSettingsIOS = IOSInitializationSettings(
    onDidReceiveLocalNotification: (id, title, body, payload) async {
      print(
          'Received Notification: ID: $id, Title: $title, Body: $body, Payload: $payload');
      return null;
    },
  );

  var initializationSettings = InitializationSettings(
      initializationSettingsAndroid, initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onSelectNotification: (String payload) async {
      if (payload != null) {
        debugPrint('notification payload: ' + payload);
      }
      return null;
    },
  );

  runApp(MyApp());

  /* ***********************************************************************
    Background Task Setup
  *************************************************************************/
  // Register to receive BackgroundFetch events after app is terminated.
  // Requires {stopOnTerminate: false, enableHeadless: true}
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Pedometer Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  //MyHomePage({Key key, this.title}) : super(key: key);

  //final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  int localNotificationId = 1; // Step update notification id
  AppLifecycleState _notification; // To track the app foreground and background
  TimeConverter _timeConverter = TimeConverter();
  int _bottomNavIndex = 0; // Bottom Navigation control
  List<Widget> _screenWidgetList = [];
  final List<String> _screenTitleList = ['Pedometer', 'Health', 'BG Task'];

  /* *********************************************************
    Declare variables for Pedometer
  ***********************************************************/
  Pedometer _pedometer;
  StreamSubscription<int> _subscription;
  static List<String> _stepValList = [];
  int _stepLatest = 0;
  List<String> _pedometerError = [];
  String pedometerDone = '';

  /* *********************************************************
    Declare variables for Health
  ***********************************************************/
  var _healthKitOutput;
  var _healthDataList = List<HealthDataPoint>();
  bool _isAuthorized = false;
  List<String> _healthDataStringList = [];
  String _lastUpdated;

  /* *********************************************************
    Declare variables for Background Fetch
  ***********************************************************/
  bool _enabled = true;
  int _status = 0;
  List<String> _events = [];

  /* *********************************************************
    App Life Cycle
  ***********************************************************/
  // state == AppLifecycleState.inactive  means app is in BG
  // state == AppLifecycleState.resumed  means app is on FG
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    print('App State changed: $state');
    if (state == AppLifecycleState.inactive && state != _notification) {
      _fireLocalNotificationAppBackground();

      setState(() {
        _notification = state;
        _stepValList.add(
            "[${_timeConverter.fromDateTime(DateTime.now())}]\n App on Background");

        _setViewWidgets();
      });
    } else if (state == AppLifecycleState.resumed && state != _notification) {
      setState(() {
        _notification = state;
        _stepValList.add(
            "[${_timeConverter.fromDateTime(DateTime.now())}]\n App on Foreground");
        _setViewWidgets();
      });
    } else {
      print('Other cases...');
    }
  }

  @override
  void initState() {
    setState(() {
      _screenWidgetList = [
        PedometerView(
            stepValList: _stepValList, pedometerError: _pedometerError),
        HealthView(
          healthDataStringList: _healthDataStringList,
        ),
      ];
    });
    WidgetsBinding.instance.addObserver(this); // Tracks the app FG / BG

   
    
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> initPlatformState() async {
    _startPedometer();
    _startHealth();
    _startBackgroundTaskConfig(); // Config also start background task
  }

  void _setViewWidgets() {
    _screenWidgetList = [
      PedometerView(stepValList: _stepValList, pedometerError: _pedometerError),
      HealthView(
        healthDataStringList: _healthDataStringList,
        lastUpdated: _lastUpdated,
      ),
      BackgroundTaskView(events: _events),
    ];
  }

  void _fireLocalNotificationAppBackground() async {
    /// Call Local Notification
    var scheduledNotificationDateTime =
        DateTime.now().add(Duration(seconds: 2));
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'your other channel id',
        'your other channel name',
        'your other channel description');
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    NotificationDetails platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.schedule(
        0,
        'App on Background',
        'Steps: $_stepLatest',
        scheduledNotificationDateTime,
        platformChannelSpecifics);
  }

  Future<void> _fireLocalNotificationStepChanged() async {
    /// Call Local Notification
    var scheduledNotificationDateTime =
        DateTime.now().add(Duration(seconds: 10));
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'your other channel id',
        'your other channel name',
        'your other channel description');
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    NotificationDetails platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.schedule(
        localNotificationId,
        'Steps Updated',
        '[ID: $localNotificationId] Steps: $_stepLatest',
        scheduledNotificationDateTime,
        platformChannelSpecifics);

    setState(() {
      localNotificationId++;
    });

    return ;
  }

  Future<void> _fireLocalNotificationHealthUpdate() async {
    // Update Health
    await _startHealth();
    List<String> healthDataList = _healthDataStringList.reversed.toList();
    String healthData = 'NA';
    if (_healthDataStringList.length > 0) healthData = healthDataList[0];

    var scheduledNotificationDateTime =
        DateTime.now().add(Duration(seconds: 10));
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'your other channel id',
        'your other channel name',
        'your other channel description');
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    NotificationDetails platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.schedule(
        localNotificationId,
        'Health Updated',
        '[ID: $localNotificationId] Health Data: $healthData',
        scheduledNotificationDateTime,
        platformChannelSpecifics);

    setState(() {
      localNotificationId++;
    });
  }

  /* *********************************************************
    Pedometer Setup
  ***********************************************************/
  void _startPedometer() {
    _pedometer = new Pedometer();
    _subscription = _pedometer.pedometerStream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: true,
    );
  }

  void _onData(int receivedData) {
    print('[Pedometer] Data received: $receivedData');

    // Check the difference from latest steps
    int stepsDiff = receivedData - _stepLatest;
    if (stepsDiff >= 5 && _notification == AppLifecycleState.inactive) {
      _fireLocalNotificationStepChanged();
    }

    // Sometimes they return the same values. We only want different values
    if (stepsDiff != 0) {
      setState(() {
        _stepLatest = receivedData;
        _stepValList.add(
            "[${_timeConverter.fromDateTime(DateTime.now())}]\n Step: $receivedData");

        _setViewWidgets();
      });
    }
  }

  void _onError(err) {
    print('[Pedometer] Error: $err');
    setState(() {
      _pedometerError.add(
          '[${_timeConverter.fromDateTime(DateTime.now())}]\n Pedometer Error: $err');

      _setViewWidgets();
    });
  }

  void _onDone() {
    print('[Pedometer] Done');
    setState(() {
      _stepValList.add(
          "[${_timeConverter.fromDateTime(DateTime.now())}]\n Step done is called...");
      _setViewWidgets();
    });
  }

  /* *********************************************************
    Health Setup (Request authorization and choose data types)
  ***********************************************************/
  Future<void> _startHealth() async {
    /// Set the range of data
    DateTime startDate = DateTime(2020, 05, 28);
    DateTime endDate = DateTime.now();

    Future.delayed(Duration(seconds: 1), () async {
      _isAuthorized = await Health.requestAuthorization();

      if (_isAuthorized) {
        /// Check if Steps data is available
        bool stepsAvailable = Health.isDataTypeAvailable(HealthDataType.STEPS);
        print("is WEIGHT data type available?: $stepsAvailable");

        if (stepsAvailable) {
          _healthDataList = []; // Empty to prevent keep stacking
          try {
            /// If available, get the data
            List<HealthDataPoint> healthData =
                await Health.getHealthDataFromType(
                    startDate, endDate, HealthDataType.STEPS);
            _healthDataList.addAll(healthData);
          } catch (exception) {
            print(exception.toString());
          }

          /// Form data into string to see on the screen.
          List<String> tempList = [];
          _healthDataList.forEach((stepsDataPoint) {
            tempList.add(
                'Duration: [ ${_timeConverter.calcDuration(Duration(milliseconds: stepsDataPoint.dateTo - stepsDataPoint.dateFrom))} ] \n${DateTime.fromMillisecondsSinceEpoch(stepsDataPoint.dateFrom)} \n${DateTime.fromMillisecondsSinceEpoch(stepsDataPoint.dateTo)} \nSteps: ${stepsDataPoint.value}');
          });

          /// Update the UI to display the results
          setState(() {
            _healthDataStringList = tempList;
            _lastUpdated = _timeConverter.fromDateTime(DateTime.now());
            _setViewWidgets();
          });
        } else {
          /// Steps data not available
        }
      } else {
        /// Not authorized
      }
    });
  }

  /* *********************************************************
    Background Task Setup
  ***********************************************************/
  Future<void> _startBackgroundTaskConfig() async {
    // Load persisted fetch events from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String json = prefs.getString(EVENTS_KEY);
    if (json != null) {
      setState(() {
        _events = jsonDecode(json).cast<String>();
      });
    }

    // Configure BackgroundFetch.
    BackgroundFetch.configure(
            BackgroundFetchConfig(
                minimumFetchInterval: 15,
                stopOnTerminate: false,
                enableHeadless: false,
                requiresBatteryNotLow: false,
                requiresCharging: false,
                requiresStorageNotLow: false,
                requiresDeviceIdle: false,
                startOnBoot: true,
                forceAlarmManager: true,
                requiredNetworkType: NetworkType.NONE),
            _onBackgroundTask)
        .then((int status) {

      print('[BackgroundFetch] configure success: $status');
      setState(() {
        _status = status;
      });
    }).catchError((e) {
      print('[BackgroundFetch] configure ERROR: $e');
      setState(() {
        _status = e;
      });
    });

    
    //_scheduleEveryInterval();

    BackgroundFetch.scheduleTask(TaskConfig(
        taskId: "com.transistorsoft.pedometer",
        delay: 10000,
        periodic: false,
        forceAlarmManager: true,
        stopOnTerminate: false,
        enableHeadless: true
    ));

    // Optionally query the current BackgroundFetch status.
    int status = await BackgroundFetch.status;
    setState(() {
      _status = status;
    });

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  _scheduleEveryInterval() {
    // For example, 10 min.
    for(var i = 1; i <= 12; i++) {
      BackgroundFetch.scheduleTask(TaskConfig(
        taskId: "taehoon.Background.$i",
        delay: 1000 * 60 * 10 * i,
        periodic: true
        ));
    }
    
  }

  _onBackgroundTask(String taskId) async {
    print("[BackgroundFetch][onBGTask] Event received: $taskId");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime timestamp = new DateTime.now();
    // This is the fetch-event callback.
    print("[BackgroundFetch] Event received: $taskId");
    String message = "[${_timeConverter.fromDateTime(DateTime.now())}][BackgroundTask][Task ID: $taskId]\n Step: $_stepLatest";
    setState(() {
      _events.insert(0, message);
    });
    // Persist fetch events in SharedPreferences
    prefs.setString(EVENTS_KEY, jsonEncode(_events));

    // setState(() {
    //     _stepValList.add(
    //         "[${_timeConverter.fromDateTime(DateTime.now())}][BackgroundTask][Task ID: $taskId]\n Step: $_stepLatest");
    //   });

    if (taskId == "flutter_background_fetch") {
      // Schedule a one-shot task when fetch event received (for testing).
      BackgroundFetch.scheduleTask(TaskConfig(
          taskId: "com.transistorsoft.pedometer",
          delay: 5000,
          periodic: false,
          forceAlarmManager: true,
          stopOnTerminate: false,
          enableHeadless: true
      ));
    }

    //await _fireLocalNotificationStepChanged();

    await _setBackgroundTaskRecord(message);

    BackgroundFetch.finish(taskId);
  }

  Future<void> _setBackgroundTaskRecord(String message) async {
    var encodedMessage = Uri.encodeFull(message);
    await http.get('https://us-central1-petobe-db-admin.cloudfunctions.net/updateBackgroundTaskRecord?record=$encodedMessage');
  }

  /* *********************************************************
    Widgets
  ***********************************************************/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitleList[_bottomNavIndex]),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.white,
              size: 30,
            ),
            onPressed: _startHealth,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: (selectedNavIndex) {
          setState(() {
            _bottomNavIndex = selectedNavIndex;
          });
        },
        currentIndex:
            _bottomNavIndex, // this will be set when a new tab is tapped
        items: [
          BottomNavigationBarItem(
            icon: new Icon(Icons.directions_walk),
            title: new Text('Steps'),
          ),
          BottomNavigationBarItem(
            icon: new Icon(Icons.fitness_center),
            title: new Text('Health'),
          ),
          BottomNavigationBarItem(
            icon: new Icon(Icons.airline_seat_individual_suite),
            title: new Text('BG Task'),
          ),
        ],
      ),
      body: _screenWidgetList[_bottomNavIndex],
    );
  }
}
