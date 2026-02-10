import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_gate.dart';
import 'services/firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Clean up notifications older than 3 days on every app start
  FirestoreService.cleanupOldNotifications();
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
