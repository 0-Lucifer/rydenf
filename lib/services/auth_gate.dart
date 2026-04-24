import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/login_screen.dart';
import '../screens/email_verification_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../widgets/main_wrapper.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Whether the initial auth + privacy check is done
  bool _ready = false;
  // Whether the user has accepted the privacy policy
  bool _privacyAccepted = false;
  bool _privacyChecked = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Check privacy policy acceptance first
    final accepted = await PrivacyPolicyScreen.hasAccepted();
    if (mounted) {
      setState(() {
        _privacyAccepted = accepted;
        _privacyChecked = true;
      });
    }

    // If privacy not accepted, stop here — show the policy screen
    if (!accepted) return;

    // Wait for Firebase Auth to restore any persisted session.
    // authStateChanges() fires immediately with the cached user (or null).
    // We await its first emission so we never flash the login screen.
    await FirebaseAuth.instance.authStateChanges().first;

    // Keep local login flag in sync for any other code that reads it
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await AuthService.saveLoginLocally(user.uid);
    }

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  void _onPrivacyAccepted() {
    setState(() => _privacyAccepted = true);
    // Re-run the auth restoration now that privacy is accepted
    _initAuth();
  }

  Future<void> _initAuth() async {
    await FirebaseAuth.instance.authStateChanges().first;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await AuthService.saveLoginLocally(user.uid);
    }

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still checking privacy acceptance
    if (!_privacyChecked) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7CF6)),
        ),
      );
    }

    // Privacy policy not yet accepted — show it
    if (!_privacyAccepted) {
      return PrivacyPolicyScreen(onAccepted: _onPrivacyAccepted);
    }

    // Still waiting for Firebase to restore the session
    if (!_ready) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7CF6)),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Waiting for the stream's first emission
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7CF6)),
            ),
          );
        }

        final user = snapshot.data;

        // Not logged in
        if (user == null) {
          return const LoginScreen();
        }

        // Logged in but email NOT verified
        if (!user.emailVerified) {
          return const EmailVerificationScreen();
        }

        // Logged in & verified → ensure profile exists, then go to app
        FirestoreService.ensureUserProfile();
        return const MainWrapper();
      },
    );
  }
}

