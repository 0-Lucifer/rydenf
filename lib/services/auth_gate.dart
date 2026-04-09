import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/login_screen.dart';
import '../screens/email_verification_screen.dart';
import '../widgets/main_wrapper.dart';
import 'firestore_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Track whether the stream has emitted a real value at least once.
  // This prevents showing LoginScreen during the brief initial null
  // emission that happens before Firebase restores the persisted session.
  bool _initialAuthResolved = false;

  @override
  void initState() {
    super.initState();
    // If there's already a persisted user, mark as resolved immediately
    if (FirebaseAuth.instance.currentUser != null) {
      _initialAuthResolved = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still waiting for the very first emission
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7CF6)),
            ),
          );
        }

        // Once we get real data, mark as resolved
        if (snapshot.hasData && snapshot.data != null) {
          _initialAuthResolved = true;
        }

        // If we haven't resolved yet and data is null, keep showing
        // the loading spinner — the persisted session is still restoring.
        if (!_initialAuthResolved && (snapshot.data == null)) {
          // Give Firebase a moment; show splash instead of LoginScreen
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_initialAuthResolved) {
              setState(() => _initialAuthResolved = true);
            }
          });
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7CF6)),
            ),
          );
        }

        // Not logged in (genuinely)
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // Logged in but email NOT verified
        if (!snapshot.data!.emailVerified) {
          return const EmailVerificationScreen();
        }

        // Logged in & verified → ensure profile exists, then go to app
        FirestoreService.ensureUserProfile();
        return const MainWrapper();
      },
    );
  }
}
