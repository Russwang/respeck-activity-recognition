import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'globals.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'home.dart';

// This file starts the app and displays the home screen.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read app version information
  PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
    appVersionName = packageInfo.version; // App version
    appVersionCode = int.tryParse(packageInfo.buildNumber) ?? 1; // Build number
  });

  // Read pairing information form shared preferences
  respeckUUID = await asyncPrefs.getString('rid');

  subjectID = await asyncPrefs.getString('sid');

  // get storage folder - must be accessible to the user for PDIoT
  storageFolder = await getDownloadsDirectory();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pdiot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: "PDIoT"),
    );
  }
}
