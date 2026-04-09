import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'services/auth_gate.dart';
import 'services/local_notification_service.dart';
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

  // ⚠️ ONE-TIME SEED 
  //await seedAppConfig(minAppVersion: '1.0.0');
  // ⚠️ END ONE-TIME SEED

  // Fire-and-forget stale data cleanup (runs in background)
  FirestoreService.cleanupOldNotifications();
  FirestoreService.cleanupOldRides();
  FirestoreService.cleanupExpiredGroupRides();
  FirestoreService.cleanupExpiredChats();
  FirestoreService.cleanupExpiredRides();

  runApp(const RydenApp());
}

class RydenApp extends StatelessWidget {
  const RydenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.transparent),
      ),
      home: const AuthGate(),
    );
  }
}
