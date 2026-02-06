import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() => runApp(const RydenApp());

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
      home: const LoginScreen(),
    );
  }
}
