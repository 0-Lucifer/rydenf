import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/ride_model.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  // ─── User Profile ──────────────────────────────────────

  /// Create a new user profile document (called after sign-up)
  static Future<void> createUserProfile({
    required String uid,
    required String email,
    String displayName = '',
    String studentId = '',
    String phone = '',
    String gender = '',
  }) async {
    try {
      final docRef = _db.collection('users').doc(uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        final profile = UserProfile(
          uid: uid,
          email: email,
          displayName: displayName,
          studentId: studentId,
          phone: phone,
          gender: gender,
        );
        await docRef.set(profile.toMap());
      }
    } catch (e) {
      print('[FirestoreService] Error creating user profile: $e');
    }
  }

  /// Ensure the current user has a profile document (called on login)
  static Future<void> ensureUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final docRef = _db.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        final profile = UserProfile(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
        );
        await docRef.set(profile.toMap());
      }
    } catch (e) {
      print('[FirestoreService] Error ensuring user profile: $e');
    }
  }

  /// Get the current user's profile as a stream (real-time)
  static Stream<UserProfile?> getUserProfileStream() {
    if (_uid == null) return Stream.value(null);
    return _db.collection('users').doc(_uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromMap(doc.data()!);
    }).handleError((error) {
      print('[FirestoreService] Error streaming user profile: $error');
      return null;
    });
  }

  /// Get any user's profile once (for showing driver info on ride cards)
  static Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromMap(doc.data()!);
    } catch (e) {
      print('[FirestoreService] Error getting user profile: $e');
      return null;
    }
  }

  /// Update the current user's profile fields
  static Future<({bool success, String message})> updateUserProfile(Map<String, dynamic> data) async {
    if (_uid == null) {
      return (success: false, message: 'Not signed in.');
    }
    try {
      await _db.collection('users').doc(_uid).update(data);
      return (success: true, message: 'Profile updated successfully!');
    } catch (e) {
      print('[FirestoreService] Error updating user profile: $e');
      return (success: false, message: 'Failed to update profile. Please try again.');
    }
  }

  // ─── Rides ─────────────────────────────────────────────

  /// Publish a new ride to Firestore
  static Future<({bool success, String message})> publishRide(Ride ride) async {
    try {
      await _db.collection('rides').add(ride.toMap());
      return (success: true, message: 'Ride published successfully!');
    } catch (e) {
      print('[FirestoreService] Error publishing ride: $e');
      return (success: false, message: 'Failed to publish ride. Please try again.');
    }
  }

  /// Stream all active rides (real-time updates for Available Rides screen)
  static Stream<List<Ride>> getAvailableRidesStream() {
    return _db
        .collection('rides')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Ride.fromMap(doc.data(), doc.id))
            .where((ride) => ride.status == 'active')
            .toList())
        .handleError((error) {
          print('[FirestoreService] Error streaming available rides: $error');
          return <Ride>[];
        });
  }

  /// Stream rides created by the current user
  static Stream<List<Ride>> getUserRidesStream() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('rides')
        .where('driverId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Ride.fromMap(doc.data(), doc.id))
            .toList())
        .handleError((error) {
          print('[FirestoreService] Error streaming user rides: $error');
          return <Ride>[];
        });
  }

  /// Cancel a ride (set status to cancelled)
  static Future<({bool success, String message})> cancelRide(String rideId) async {
    try {
      await _db.collection('rides').doc(rideId).update({'status': 'cancelled'});
      return (success: true, message: 'Ride cancelled.');
    } catch (e) {
      print('[FirestoreService] Error cancelling ride: $e');
      return (success: false, message: 'Failed to cancel ride.');
    }
  }
}
