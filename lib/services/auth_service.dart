import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Local persistence keys
  static const String _loginUidKey = 'ryden_logged_in_uid';

  /// Save login state to device so it survives app kills
  static Future<void> _saveLoginLocally(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_loginUidKey, uid);
  }

  /// Clear saved login state (called on logout)
  static Future<void> _clearLocalLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginUidKey);
  }

  /// Check if user was previously logged in (for cold-start detection)
  static Future<String?> getSavedLoginUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_loginUidKey);
  }

  // ─── Domain Restriction ──────────────────────────────
  static const String _allowedDomain = 'northsouth.edu';

  static bool isValidUniversityEmail(String email) {
    final trimmed = email.trim().toLowerCase();
    return trimmed.endsWith('@$_allowedDomain');
  }

  // ─── Current User ────────────────────────────────────
  static User? get currentUser => _auth.currentUser;
  static bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Sign Up ─────────────────────────────────────────
  static Future<({bool success, String message})> signUp({
    required String email,
    required String password,
    required String displayName,
    String studentId = '',
    String phone = '',
    String gender = '',
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (!isValidUniversityEmail(trimmedEmail)) {
      return (
        success: false,
        message: 'Only @northsouth.edu email addresses are allowed.',
      );
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      // Set display name on Firebase Auth user
      await credential.user?.updateDisplayName(displayName.trim());

      // Send verification email
      await credential.user?.sendEmailVerification();

      // Create user profile in Firestore with all fields
      if (credential.user != null) {
        await FirestoreService.createUserProfile(
          uid: credential.user!.uid,
          email: trimmedEmail,
          displayName: displayName.trim(),
          studentId: studentId.trim(),
          phone: phone.trim(),
          gender: gender,
        );
      }

      return (
        success: true,
        message: 'Account created! Please check your NSU email for verification.',
      );
    } on FirebaseAuthException catch (e) {
      return (success: false, message: _mapFirebaseError(e.code));
    } catch (e) {
      return (success: false, message: 'Something went wrong. Please try again.');
    }
  }

  // ─── Sign In ─────────────────────────────────────────
  static Future<({bool success, String message, bool needsVerification})> signIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (!isValidUniversityEmail(trimmedEmail)) {
      return (
        success: false,
        message: 'Only @northsouth.edu email addresses are allowed.',
        needsVerification: false,
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      if (credential.user != null && !credential.user!.emailVerified) {
        return (
          success: false,
          message: 'Please verify your email before logging in.',
          needsVerification: true,
        );
      }

      // Persist login locally so it survives app kills
      if (credential.user != null) {
        await _saveLoginLocally(credential.user!.uid);
      }

      return (
        success: true,
        message: 'Welcome back!',
        needsVerification: false,
      );
    } on FirebaseAuthException catch (e) {
      return (
        success: false,
        message: _mapFirebaseError(e.code),
        needsVerification: false,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Something went wrong. Please try again.',
        needsVerification: false,
      );
    }
  }

  // ─── Sign Out ────────────────────────────────────────
  static Future<void> signOut() async {
    FirestoreService.clearStreamCaches();
    await _clearLocalLogin();
    await _auth.signOut();
  }

  // ─── Password Reset ──────────────────────────────────
  static Future<({bool success, String message})> sendPasswordReset(String email) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (!isValidUniversityEmail(trimmedEmail)) {
      return (
        success: false,
        message: 'Only @northsouth.edu email addresses are allowed.',
      );
    }

    try {
      await _auth.sendPasswordResetEmail(email: trimmedEmail);
      return (
        success: true,
        message: 'Password reset email sent! Check your NSU inbox.',
      );
    } on FirebaseAuthException catch (e) {
      return (success: false, message: _mapFirebaseError(e.code));
    } catch (e) {
      return (success: false, message: 'Something went wrong. Please try again.');
    }
  }

  // ─── Resend Verification ─────────────────────────────
  static Future<({bool success, String message})> resendVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return (
        success: true,
        message: 'Verification email resent! Check your inbox.',
      );
    } catch (e) {
      return (
        success: false,
        message: 'Could not send email. Please try again later.',
      );
    }
  }

  // ─── Reload & Check Verification ─────────────────────
  static Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // ─── Error Mapping ───────────────────────────────────
  static String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
