import 'dart:async';
import 'models/prediction.dart';
import 'services/activity_history.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'settings.dart';
import 'utils.dart';
import 'ble.dart';
import 'globals.dart';
import 'dart:io';
import 'har_service.dart';
import 'social_signal_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'history.dart';

// The home page includes buttons to connect to the respeck, enter capture
// metadata and start recording.

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  //String _counter = "---";
  String accel = ""; // Holds live accelerometer readings (x, y, z)
  String batteryText = ""; // Displays battery level and charging status
  String recordingInfo = "Not recording"; // Shows recording state
  String predictedActivity =
      "HAR not initialized"; // HAR model status or prediction
  int harBufferSize = 0;
  String harConfidenceStr = "---";
  String socialSignalPrediction = "Social signal not initialized";

  ActivityHistory _history = ActivityHistory();
  Timer? _saveTimer;
  bool _historyLoaded = false;
  bool connecting = false;
  bool modelsReady = false;
  Future<void> _pendingSave = Future.value();

  // Predefined physical activities
  var activities = [
    'Standing',
    'Lying down on left',
    'Lying down right',
    'Lying down back',
    'Lying down on stomach',
    'Normal walking',
    'Ascending stairs',
    'Descending stairs',
    'Shuffle walking',
    'Running',
    'Miscellaneous movements'
  ];
  String selectedActivity = "Standing";

  // Predefined social signals
  var socialSignals = [
    'Normal',
    'Coughing',
    'Hyperventilating',
    'Talking',
    'Eating',
    'Singing',
    'Laughing'
  ];
  String selectedSignal = "Normal";

  bool recording = false;
  bool receivedPacket = false;

  int recordedSamples = 0;
  DateTime? startTimestamp;

  String filename = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeHAR();
    _loadStats();
    _saveTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _saveStats());
  }

  Future<void> _saveStats() {
    if (!_historyLoaded) return Future.value();
    final snapshot = jsonEncode(_history.milliseconds);
    _pendingSave = _pendingSave.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('history_v2_ms', snapshot);
    }).catchError((Object error) {
      debugPrint('Cannot save history: $error');
    });
    return _pendingSave;
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString('history_v2_ms');
      if (text != null) {
        final decoded = jsonDecode(text) as Map<String, dynamic>;
        final totals = decoded.map(
            (day, value) => MapEntry(day, Map<String, int>.from(value as Map)));
        if (mounted) _history = ActivityHistory(totals);
      }
    } catch (e) {
      debugPrint('Cannot load history: $e');
    }
    // Legacy `history` remains untouched: its timing data is unreliable.
    if (mounted) setState(() => _historyLoaded = true);
  }

  Future<void> _initializeHAR() async {
    final harOK = await HARService.initialize();
    if (!mounted) {
      HARService.dispose();
      return;
    }
    final socialOK = await SocialSignalService.initialize();
    if (!mounted) {
      HARService.dispose();
      SocialSignalService.dispose();
      return;
    }
    setState(() {
      modelsReady = harOK && socialOK;
      predictedActivity = harOK
          ? 'HAR ready - waiting for data...'
          : 'HAR initialization failed';
      socialSignalPrediction = socialOK
          ? 'Social signal model ready - waiting for data...'
          : 'Social signal initialization failed';
    });
  }

  void onDisconnected() {
    if (!mounted) return;
    _history.resetSession();
    HARService.clearBuffer();
    SocialSignalService.clearBuffer();
    setState(() {
      receivedPacket = false;
      recording = false;
      recordingInfo = 'Disconnected';
    });
    _saveStats();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _history.resetSession();
      _saveStats();
    }
  }

  // Method to update UI from BLE data processing
  // This function is called by the BLE module whenever new data is received.
  // It updates:
  // - Live accelerometer readings
  // - Battery level and charging status
  // - HAR prediction or model status
  // The setState() call ensures the screen refreshes automatically after updates.

  void updateUI({
    required double x,
    required double y,
    required double z,
    int? batteryLevel,
    bool isCharging = false,
    required int respeckVersion,
    Prediction? prediction,
    Prediction? socialPrediction,
    double? confidence,
    required int bufferSize,
  }) {
    if (!mounted) return;
    if (_historyLoaded &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _history.update(DateTime.now(), prediction, socialPrediction);
    }
    setState(() {
      accel =
          "x=${x.toStringAsFixed(3)}, y=${y.toStringAsFixed(3)}, z=${z.toStringAsFixed(3)}";

      if (respeckVersion == 6) {
        if (isCharging) {
          batteryText = "Battery: $batteryLevel% (charging)";
        } else {
          batteryText = "Battery: $batteryLevel%";
        }
      } else {
        batteryText = "";
      }

      if (prediction != null) {
        if (confidence != null) {
          predictedActivity =
              "$prediction (${(confidence * 100).toStringAsFixed(1)}%)";
        } else {
          predictedActivity = prediction.toString();
        }
      } else {
        predictedActivity =
            "Collecting data... ($bufferSize/${HARService.windowSize} samples)";
      }

      if (socialPrediction != null) {
        socialSignalPrediction = socialPrediction.toString();
      } else {
        socialSignalPrediction = "Collecting social signal data...";
      }

      harBufferSize = bufferSize;
      if (confidence != null) {
        harConfidenceStr = "${(confidence * 100).toStringAsFixed(1)}%";
      } else {
        harConfidenceStr = "---";
      }
    });
  }

  // When leaving the home screen, the HAR interpreter and buffer are cleared.
  // Prevents memory leaks or duplicate models being loaded if the user navigates away.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _saveStats();
    HARService.dispose();
    SocialSignalService.dispose();
    super.dispose();
  }

  // The UI for the main screen of the app is defined below. Unlike traditional
  // android code, there is no additional XML layout file.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                  onPressed: connecting ||
                          receivedPacket ||
                          !modelsReady ||
                          !_historyLoaded
                      ? null
                      : () async {
                          if (respeckUUID == null || respeckUUID == "") {
                            showToast("Please pair with a Respeck first");
                            return;
                          }
                          setState(() => connecting = true);
                          try {
                            await scanForRespeck(this);
                          } catch (e) {
                            onDisconnected();
                            showToast('Connection failed: $e');
                          } finally {
                            if (mounted) setState(() => connecting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue),
                  child: const Text('Connect')),
              const SizedBox(height: 20),
              const Text(
                'Acceleration (g)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                accel,
              ),
              Text(
                batteryText,
              ),
              const SizedBox(height: 20),
              const Text(
                'Real-time Activity Recognition',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  predictedActivity,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Real-time Social Signal Recognition',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  socialSignalPrediction,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "🔧 Debug info",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        "Buffer size: $harBufferSize / ${HARService.windowSize}"),
                    Text("HAR Predicted class: $predictedActivity"),
                    Text("Social Predicted: $socialSignalPrediction"),
                    // Text("Confidence: $harConfidenceStr"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Activity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton(
                // Initial Value
                value: selectedActivity,
                items: activities.map((String items) {
                  return DropdownMenuItem(value: items, child: Text(items));
                }).toList(),
                // After selecting the desired option,it will
                // change button value to selected value
                onChanged: (String? newValue) {
                  setState(() {
                    selectedActivity = newValue!;
                  });
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Social signal',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton(
                // Initial Value
                value: selectedSignal,
                items: socialSignals.map((String items) {
                  return DropdownMenuItem(value: items, child: Text(items));
                }).toList(),
                // After selecting the desired option,it will
                // change button value to selected value
                onChanged: (String? newValue) {
                  setState(() {
                    selectedSignal = newValue!;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: record,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightGreen),
                  child: const Text('Start recording')),
              const SizedBox(height: 20),
              const Text(
                "Recording status",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                recordingInfo,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  filename,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: () {
                    if (!recording) {
                      return;
                    }
                    recording = false;
                    showToast("Recording stopped");
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[200]!),
                  child: const Text('Stop recording')),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Settings')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          HistoryPage(stats: _history.milliseconds),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text('History'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Start recording respeck data to CSV
  void record() async {
    if (!receivedPacket) {
      showToast("Please connect to a Respeck first");
      return;
    }
    if (recording) {
      showToast("Already recording");
      return;
    }

    if (storageFolder == null) {
      showToast('Recording folder is unavailable');
      return;
    }
    recordedSamples = 0;
    DateTime now =
        DateTime.now().toUtc(); //use current UTC timestamp for filename
    startTimestamp = now;
    String formattedDate =
        '${DateFormat('yyyy-MM-dd').format(now)}T${DateFormat('kkmmss').format(now)}Z';
    filename =
        'PDIOT_${subjectID}_${sentenceToCamelCase(selectedActivity)}_${sentenceToCamelCase(selectedSignal)}_${formattedDate}_${respeckUUID?.replaceAll(":", "")}.csv';
    debugPrint(filename);

    try {
      // create file and write CSV header row
      csvFile = File('${storageFolder?.path}/$filename');
      await csvFile.writeAsString(
          "receivedPhoneTimestamp,respeckTimestamp,packetSeqNum,sampleSeqNum,accelX,accelY,accelZ\n",
          flush: true);
      showToast("Recording started..");
      if (!mounted || !receivedPacket) return;
      setState(() => recording = true);
    } catch (e) {
      showToast('Cannot start recording: $e');
    }
  }
}
