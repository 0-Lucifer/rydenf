import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  // ═══════════════════════════════════════════════════════
  //  USER PROFILE
  // ═══════════════════════════════════════════════════════

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

  /// Get any user's profile once
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

  // ═══════════════════════════════════════════════════════
  //  RIDES
  // ═══════════════════════════════════════════════════════

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

  /// Stream all active rides (for Available Rides screen)
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

  /// Get a single ride as a stream (for ride detail screen)
  static Stream<Ride?> getRideStream(String rideId) {
    return _db.collection('rides').doc(rideId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Ride.fromMap(doc.data()!, doc.id);
    }).handleError((error) {
      print('[FirestoreService] Error streaming ride: $error');
      return null;
    });
  }

  /// Cancel a ride (driver cancels entire ride)
  static Future<({bool success, String message})> cancelRide(String rideId) async {
    try {
      final batch = _db.batch();

      // Cancel the ride
      batch.update(_db.collection('rides').doc(rideId), {'status': 'cancelled'});

      // Cancel all pending/accepted requests for this ride
      final requests = await _db
          .collection('ride_requests')
          .where('rideId', isEqualTo: rideId)
          .get();

      for (final doc in requests.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'pending' || status == 'accepted') {
          batch.update(doc.reference, {'status': 'cancelled'});
        }
      }

      await batch.commit();
      return (success: true, message: 'Ride cancelled.');
    } catch (e) {
      print('[FirestoreService] Error cancelling ride: $e');
      return (success: false, message: 'Failed to cancel ride.');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  RIDE REQUESTS (BOOKING)
  // ═══════════════════════════════════════════════════════

  /// Request a seat on a ride
  static Future<({bool success, String message})> requestRide({
    required String rideId,
    required bool instantBooking,
    int seatsRequested = 1,
  }) async {
    if (_uid == null) return (success: false, message: 'Not signed in.');

    try {
      // Get passenger name from profile
      final profile = await getUserProfile(_uid!);
      final passengerName = profile?.displayName ?? _auth.currentUser?.email?.split('@').first ?? 'Unknown';

      // Check if user already has a pending/accepted request for this ride
      final existing = await _db
          .collection('ride_requests')
          .where('rideId', isEqualTo: rideId)
          .where('passengerId', isEqualTo: _uid)
          .get();

      final hasActiveRequest = existing.docs.any((doc) {
        final s = doc.data()['status'] as String?;
        return s == 'pending' || s == 'accepted';
      });

      if (hasActiveRequest) {
        return (success: false, message: 'You already have a booking for this ride.');
      }

      // Check seat availability
      final rideDoc = await _db.collection('rides').doc(rideId).get();
      if (!rideDoc.exists) return (success: false, message: 'Ride not found.');
      final rideData = rideDoc.data()!;
      final seatsAvailable = rideData['seatsAvailable'] as int? ?? 0;

      if (seatsAvailable < seatsRequested) {
        return (success: false, message: 'Not enough seats available.');
      }

      final request = RideRequest(
        rideId: rideId,
        passengerId: _uid!,
        passengerName: passengerName,
        seatsRequested: seatsRequested,
        status: instantBooking ? 'accepted' : 'pending',
      );

      final batch = _db.batch();
      final requestRef = _db.collection('ride_requests').doc();
      batch.set(requestRef, request.toMap());

      // If instant booking, immediately accept: decrement seats + add to passengers
      if (instantBooking) {
        final newSeats = seatsAvailable - seatsRequested;
        final updates = <String, dynamic>{
          'seatsAvailable': newSeats,
          'passengers': FieldValue.arrayUnion([_uid]),
        };
        if (newSeats <= 0) {
          updates['status'] = 'full';
        }
        batch.update(_db.collection('rides').doc(rideId), updates);
      }

      await batch.commit();

      return (
        success: true,
        message: instantBooking ? 'Seat booked successfully!' : 'Request sent! Waiting for driver approval.',
      );
    } catch (e) {
      print('[FirestoreService] Error requesting ride: $e');
      return (success: false, message: 'Failed to request ride. Please try again.');
    }
  }

  /// Accept a ride request (driver action)
  static Future<({bool success, String message})> acceptRequest(String requestId) async {
    try {
      final requestDoc = await _db.collection('ride_requests').doc(requestId).get();
      if (!requestDoc.exists) return (success: false, message: 'Request not found.');

      final data = requestDoc.data()!;
      final rideId = data['rideId'] as String;
      final passengerId = data['passengerId'] as String;
      final seatsRequested = data['seatsRequested'] as int? ?? 1;

      // Check seat availability
      final rideDoc = await _db.collection('rides').doc(rideId).get();
      final seatsAvailable = rideDoc.data()?['seatsAvailable'] as int? ?? 0;

      if (seatsAvailable < seatsRequested) {
        return (success: false, message: 'Not enough seats left.');
      }

      final batch = _db.batch();

      // Accept the request
      batch.update(requestDoc.reference, {'status': 'accepted'});

      // Update ride: decrement seats, add passenger
      final newSeats = seatsAvailable - seatsRequested;
      final updates = <String, dynamic>{
        'seatsAvailable': newSeats,
        'passengers': FieldValue.arrayUnion([passengerId]),
      };
      if (newSeats <= 0) {
        updates['status'] = 'full';
      }
      batch.update(_db.collection('rides').doc(rideId), updates);

      await batch.commit();
      return (success: true, message: 'Request accepted!');
    } catch (e) {
      print('[FirestoreService] Error accepting request: $e');
      return (success: false, message: 'Failed to accept request.');
    }
  }

  /// Reject a ride request (driver action)
  static Future<({bool success, String message})> rejectRequest(String requestId) async {
    try {
      await _db.collection('ride_requests').doc(requestId).update({'status': 'rejected'});
      return (success: true, message: 'Request rejected.');
    } catch (e) {
      print('[FirestoreService] Error rejecting request: $e');
      return (success: false, message: 'Failed to reject request.');
    }
  }

  /// Cancel a booking (passenger cancels their accepted booking)
  static Future<({bool success, String message})> cancelBooking(String requestId) async {
    try {
      final requestDoc = await _db.collection('ride_requests').doc(requestId).get();
      if (!requestDoc.exists) return (success: false, message: 'Booking not found.');

      final data = requestDoc.data()!;
      final rideId = data['rideId'] as String;
      final passengerId = data['passengerId'] as String;
      final seatsRequested = data['seatsRequested'] as int? ?? 1;
      final prevStatus = data['status'] as String;

      final batch = _db.batch();

      // Cancel the request
      batch.update(requestDoc.reference, {'status': 'cancelled'});

      // If it was accepted, restore seat and remove from passengers
      if (prevStatus == 'accepted') {
        batch.update(_db.collection('rides').doc(rideId), {
          'seatsAvailable': FieldValue.increment(seatsRequested),
          'passengers': FieldValue.arrayRemove([passengerId]),
          'status': 'active', // re-open if was full
        });
      }

      await batch.commit();
      return (success: true, message: 'Booking cancelled.');
    } catch (e) {
      print('[FirestoreService] Error cancelling booking: $e');
      return (success: false, message: 'Failed to cancel booking.');
    }
  }

  /// Stream all requests for a specific ride (driver view)
  static Stream<List<RideRequest>> getRequestsForRide(String rideId) {
    return _db
        .collection('ride_requests')
        .where('rideId', isEqualTo: rideId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideRequest.fromMap(doc.data(), doc.id))
            .toList())
        .handleError((error) {
          print('[FirestoreService] Error streaming requests: $error');
          return <RideRequest>[];
        });
  }

  /// Stream rides the current user has booked (My Bookings)
  static Stream<List<RideRequest>> getMyBookingsStream() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('ride_requests')
        .where('passengerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideRequest.fromMap(doc.data(), doc.id))
            .toList())
        .handleError((error) {
          print('[FirestoreService] Error streaming my bookings: $error');
          return <RideRequest>[];
        });
  }

  /// Get a ride once (for booking cards that need ride info)
  static Future<Ride?> getRide(String rideId) async {
    try {
      final doc = await _db.collection('rides').doc(rideId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Ride.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('[FirestoreService] Error getting ride: $e');
      return null;
    }
  }
}
