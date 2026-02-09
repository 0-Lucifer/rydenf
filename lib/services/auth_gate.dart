import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/login_screen.dart';
import '../screens/email_verification_screen.dart';
import '../widgets/main_wrapper.dart';
import 'firestore_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7CF6)),
            ),
          );
        }

        // Not logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // Logged in but email NOT verified
        if (!snapshot.data!.emailVerified) {
          return const EmailVerificationScreen();
        }

        // Logged in & verified → ensure profile exists, then go to app
        // This handles users who signed up before Firestore was integrated
        FirestoreService.ensureUserProfile();
        return const MainWrapper();
      },
    );
  }
}
