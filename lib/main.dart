import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';
import 'services/auth_gate.dart';
import 'services/local_notification_service.dart';
import 'services/background_notification_service.dart';
import 'services/firestore_service.dart';
// import 'scripts/seed_app_config.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Load environment variables (API keys)
      await dotenv.load(fileName: '.env');

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Cap Firestore offline cache at 100 MB
      FirebaseFirestore.instance.settings = const Settings(
        cacheSizeBytes: 104857600,
        persistenceEnabled: true,
      );

      // Local notifications and background service are Android/iOS only
      if (!kIsWeb) {
        await LocalNotificationService.instance.init();
        await BackgroundNotificationService.initialize();
      }

      // Prefetch the primary font family so text renders instantly
      GoogleFonts.config.allowRuntimeFetching = true;
      GoogleFonts.plusJakartaSans();

      // Fire-and-forget stale data cleanup once at startup
      FirestoreService.cleanupAllOldData();

      // Lock orientation for consistent UX (mobile only)
      if (!kIsWeb) {
        await SystemChrome.setPreferredOrientations(
            [DeviceOrientation.portraitUp]);
      }

      runApp(const RydenApp());

      // Request location permission AFTER first frame renders (mobile only)
      if (!kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _requestLocationPermission();
        });
      }
    },
    (error, stack) {
      // print() is used here (not debugPrint) so output appears in release builds
      // ignore: avoid_print
      print('[UNHANDLED ERROR] $error');
      // ignore: avoid_print
      print('[STACK] $stack');
    },
  );
}

/// Request location permission at startup so the OS dialog appears early.
Future<void> _requestLocationPermission() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[Main] Location services are disabled.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[Main] Location permission permanently denied.');
    }
  } catch (e) {
    debugPrint('[Main] Location permission request error: $e');
  }
}

class RydenApp extends StatelessWidget {
  const RydenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.transparent),
        // Faster page transitions
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const AuthGate(),
    );
  }
}
