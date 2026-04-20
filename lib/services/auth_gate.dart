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
  // Whether we've finished the initial auth check
  bool _resolved = false;
  // The result of the initial check: was the user previously logged in locally?
  bool _wasLoggedIn = false;
  // Whether the user has accepted the privacy policy
  bool _privacyAccepted = false;
  bool _privacyChecked = false;

  @override
  void initState() {
    super.initState();
    _checkPrivacyAndLogin();
  }

  Future<void> _checkPrivacyAndLogin() async {
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

    // Otherwise, proceed with the normal login check
    await _checkLocalLogin();
  }

  Future<void> _checkLocalLogin() async {
    final savedUid = await AuthService.getSavedLoginUid();
    _wasLoggedIn = savedUid != null && savedUid.isNotEmpty;

    if (_wasLoggedIn && FirebaseAuth.instance.currentUser == null) {
      // User was logged in before but Firebase hasn't restored yet.
      // Give Firebase extra time to restore the persisted session.
      for (var i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (FirebaseAuth.instance.currentUser != null) break;
      }
    }

    if (mounted) {
      setState(() => _resolved = true);
    }
  }

  void _onPrivacyAccepted() {
    setState(() => _privacyAccepted = true);
    _checkLocalLogin();
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

    // Still checking local login state
    if (!_resolved) {
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
