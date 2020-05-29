import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tester_pedometer/health_view.dart';
import 'package:flutter_tester_pedometer/pedometer_view.dart';
import 'package:flutter_tester_pedometer/util.dart';
import 'package:pedometer/pedometer.dart';
import 'package:health/health.dart';

/* ***********************************************************************
    Local Notification Setup
  *************************************************************************/
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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
  int localNotificationId = 1;    // Step update notification id
  AppLifecycleState _notification; // To track the app foreground and background
  TimeConverter _timeConverter = TimeConverter();
  int _bottomNavIndex = 0; // Bottom Navigation control
  List<Widget> _screenWidgetList = [];
  final List<String> _screenTitleList = ['Pedometer', 'Health'];

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
    _configApp();
    super.initState();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _configApp() async {
    _startPedometer();
    _startHealth();
  }

  void _setViewWidgets() {
    _screenWidgetList = [
      PedometerView(stepValList: _stepValList, pedometerError: _pedometerError),
      HealthView(
        healthDataStringList: _healthDataStringList,
        lastUpdated: _lastUpdated,
      ),
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

  void _fireLocalNotificationStepChanged() async {
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
          localNotificationId,
          'Steps Updated',
          'Steps: $_stepLatest',
          scheduledNotificationDateTime,
          platformChannelSpecifics);
      
      setState(() {
        localNotificationId++;
        if(localNotificationId > 30) localNotificationId = 1;
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
    if(stepsDiff >= 5 && _notification == AppLifecycleState.inactive) {
      _fireLocalNotificationStepChanged();
    }

    // Sometimes they return the same values. We only want different values
    if(stepsDiff != 0) {
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
  void _startHealth() {
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
        ],
      ),
      body: _screenWidgetList[_bottomNavIndex],
    );
  }
}
