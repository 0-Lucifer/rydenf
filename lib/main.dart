import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'services/auth_gate.dart';
import 'services/local_notification_service.dart';
import 'services/background_notification_service.dart';
import 'services/firestore_service.dart';
// import 'scripts/seed_app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (API keys)
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Cap Firestore offline cache at 100 MB
  FirebaseFirestore.instance.settings = const Settings(
    cacheSizeBytes: 104857600, // 100 MB
    persistenceEnabled: true,
  );

  await LocalNotificationService.instance.init();

  // Start background service to keep notifications alive when app is closed
  await BackgroundNotificationService.initialize();

  // Prefetch the primary font family so text renders instantly
  GoogleFonts.config.allowRuntimeFetching = true;
  GoogleFonts.plusJakartaSans();

  // Fire-and-forget stale data cleanup once at startup
  FirestoreService.cleanupAllOldData();

  // Lock orientation for consistent UX
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const RydenApp());
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
