import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';
import '../models/notification_model.dart';
import '../models/group_ride_model.dart';
import '../models/group_ride_request_model.dart';
import '../models/chat_room_model.dart';
import '../models/chat_message_model.dart';
import '../models/rating_model.dart';
import '../models/group_model.dart';


class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  // Cache to avoid reading the same profile over and over
  static final Map<String, _CachedProfile> _profileCache = {};
  static const _profileCacheTTL = Duration(minutes: 5);
  static void clearProfileCache() => _profileCache.clear();

  // Stream caching — avoids creating duplicate Firestore listeners
  static Stream<int>? _unreadNotifStream;
  static Stream<int>? _unreadChatStream;
  static Stream<UserProfile?>? _userProfileStream;
  static Stream<List<Ride>>? _availableRidesStream;
  static Stream<List<Ride>>? _userRidesStream;
  static Stream<Map<String, String>?>? _activeRideInfoStream;
  static String? _cachedProfileUid;
  static String? _cachedNotifUid;
  static String? _cachedChatUid;
  static String? _cachedAvailableRidesUid;
  static String? _cachedUserRidesUid;
  static String? _cachedActiveRideUid;

  /// Call on logout to clear all cached streams
  static void clearStreamCaches() {
    _unreadNotifStream = null;
    _unreadChatStream = null;
    _userProfileStream = null;
    _availableRidesStream = null;
    _userRidesStream = null;
    _activeRideInfoStream = null;
    _cachedProfileUid = null;
    _cachedNotifUid = null;
    _cachedChatUid = null;
    _cachedAvailableRidesUid = null;
    _cachedUserRidesUid = null;
    _cachedActiveRideUid = null;
    _profileCache.clear();
  }

  // Helper to split big writes into batches under 500 ops
  static Future<void> _commitInChunks(List<void Function(WriteBatch)> ops) async {
    const maxOps = 450; // leave headroom below Firestore's 500 limit
    for (var i = 0; i < ops.length; i += maxOps) {
      final batch = _db.batch();
      final end = (i + maxOps > ops.length) ? ops.length : i + maxOps;
      for (var j = i; j < end; j++) {
        ops[j](batch);
      }
      await batch.commit();
    }
  }

  // ==========================================
  //  USER PROFILE
  // ==========================================

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
      print('[FirestoreService] createUserProfile error: $e');
    }
  }

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
      print('[FirestoreService] ensureUserProfile error: $e');
    }
  }

  static Stream<UserProfile?> getUserProfileStream() {
    if (_uid == null) return Stream.value(null);
    // Return cached stream if user hasn't changed
    if (_userProfileStream != null && _cachedProfileUid == _uid) {
      return _userProfileStream!;
    }
    _cachedProfileUid = _uid;
    _userProfileStream = _db.collection('users').doc(_uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromMap(doc.data()!);
    }).handleError((error) {
      print('[FirestoreService] getUserProfileStream error: $error');
      return null;
    }).asBroadcastStream();
    return _userProfileStream!;
  }

  static Future<UserProfile?> getUserProfile(String uid) async {
    final cached = _profileCache[uid];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _profileCacheTTL) {
      return cached.profile;
    }
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      final profile = UserProfile.fromMap(doc.data()!);
      _profileCache[uid] = _CachedProfile(profile, DateTime.now());
      return profile;
    } catch (e) {
      print('[FirestoreService] getUserProfile error: $e');
      return null;
    }
  }

  static Future<({bool success, String message})> updateUserProfile(Map<String, dynamic> data) async {
    if (_uid == null) return (success: false, message: 'Not signed in.');
    try {
      await _db.collection('users').doc(_uid).update(data);
      return (success: true, message: 'Profile updated successfully!');
    } catch (e) {
      print('[FirestoreService] updateUserProfile error: $e');
      return (success: false, message: 'Failed to update profile.');
    }
  }

  // ==========================================
  //  RIDES
  // ==========================================

  static Future<({bool success, String message})> publishRide(Ride ride) async {
    try {
      // Enforce 1 active ride per user
      if (_uid != null) {
        final existing = await _db
            .collection('rides')
            .where('driverId', isEqualTo: _uid)
            .where('status', whereIn: ['active', 'full', 'in_progress'])
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          return (success: false, message: 'You already have an active ride. Cancel or complete it first.');
        }
      }
      await _db.collection('rides').add(ride.toMap());
      return (success: true, message: 'Ride published successfully!');
    } catch (e) {
      print('[FirestoreService] publishRide error: $e');
      return (success: false, message: 'Failed to publish ride.');
    }
  }

  /// Returns all active rides. Cached broadcast so multiple StreamBuilders
  /// (home screen list + upcoming rides widget) share a single Firestore listener.
  static Stream<List<Ride>> getAvailableRidesStream() {
    if (_availableRidesStream != null && _cachedAvailableRidesUid == (_uid ?? '')) {
      return _availableRidesStream!;
    }
    _cachedAvailableRidesUid = _uid ?? '';
    _availableRidesStream = _db
        .collection('rides')
        .where('status', whereIn: ['active', 'full'])
        .snapshots()
        .map((snapshot) {
          final cutoff = DateTime.now().subtract(const Duration(hours: 24));
          final rides = snapshot.docs
              .map((doc) => Ride.fromMap(doc.data(), doc.id))
              .where((ride) => ride.departureTime.isAfter(cutoff))
              .toList();
          rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rides;
        })
        .handleError((error) {
          print('[FirestoreService] getAvailableRidesStream error: $error');
          return <Ride>[];
        })
        .asBroadcastStream();
    return _availableRidesStream!;
  }

  /// Listen to rides I've created — cached broadcast to survive widget rebuilds.
  static Stream<List<Ride>> getUserRidesStream() {
    if (_uid == null) return Stream.value([]);
    if (_userRidesStream != null && _cachedUserRidesUid == _uid) {
      return _userRidesStream!;
    }
    _cachedUserRidesUid = _uid;
    _userRidesStream = _db
        .collection('rides')
        .where('driverId', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
          final rides = snapshot.docs
              .map((doc) => Ride.fromMap(doc.data(), doc.id))
              .toList();
          rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rides;
        })
        .handleError((error) {
          print('[FirestoreService] getUserRidesStream error: $error');
          return <Ride>[];
        })
        .asBroadcastStream();
    return _userRidesStream!;
  }

  /// Stream a single ride
  static Stream<Ride?> getRideStream(String rideId) {
    return _db.collection('rides').doc(rideId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Ride.fromMap(doc.data()!, doc.id);
    }).handleError((error) {
      print('[FirestoreService] getRideStream error: $error');
      return null;
    });
  }

  /// Get a ride once
  static Future<Ride?> getRide(String rideId) async {
    try {
      final doc = await _db.collection('rides').doc(rideId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Ride.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('[FirestoreService] getRide error: $e');
      return null;
    }
  }

  /// Cancel a ride (driver action) — cascades to all requests
  static Future<({bool success, String message})> cancelRide(String rideId) async {
    try {
      final batch = _db.batch();
      batch.update(_db.collection('rides').doc(rideId), {'status': 'cancelled'});

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
      print('[FirestoreService] cancelRide error: $e');
      return (success: false, message: 'Failed to cancel ride.');
    }
  }

  /// Start a ride (driver action) — transitions to in_progress
  static Future<({bool success, String message})> startRide(String rideId) async {
    try {
      final rideDoc = await _db.collection('rides').doc(rideId).get();
      final rideData = rideDoc.data();

      final batch = _db.batch();

      batch.update(_db.collection('rides').doc(rideId), {
        'status': 'in_progress',
        'startedAt': Timestamp.now(),
      });

      // Reject any still-pending requests since ride is starting
      final pending = await _db
          .collection('ride_requests')
          .where('rideId', isEqualTo: rideId)
          .get();

      for (final doc in pending.docs) {
        if (doc.data()['status'] == 'pending') {
          batch.update(doc.reference, {'status': 'rejected'});
        }
      }

      await batch.commit();

      // Notify all passengers that the ride has started
      final passengers = List<String>.from(rideData?['passengers'] ?? []);
      final origin = rideData?['origin'] ?? '';
      final destination = rideData?['destination'] ?? '';
      final driverName = rideData?['driverName'] ?? 'Driver';
      for (final pid in passengers) {
        await sendNotification(
          userId: pid,
          title: 'Ride Started! \u{1F697}',
          body: '$driverName has started the ride ($origin \u2192 $destination)',
          type: 'ride_started',
          rideId: rideId,
        );
      }

      return (success: true, message: 'Ride started!');
    } catch (e) {
      print('[FirestoreService] startRide error: $e');
      return (success: false, message: 'Failed to start ride.');
    }
  }

  /// Complete a ride (driver action)
  static Future<({bool success, String message})> completeRide(String rideId) async {
    try {
      final rideDoc = await _db.collection('rides').doc(rideId).get();
      final rideData = rideDoc.data();

      await _db.collection('rides').doc(rideId).update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
      });

      // Notify all passengers that the ride is completed
      final passengers = List<String>.from(rideData?['passengers'] ?? []);
      final origin = rideData?['origin'] ?? '';
      final destination = rideData?['destination'] ?? '';
      for (final pid in passengers) {
        await sendNotification(
          userId: pid,
          title: 'Ride Completed \u2705',
          body: 'Your ride from $origin to $destination is done. Thanks for riding!',
          type: 'ride_completed',
          rideId: rideId,
        );
      }

      return (success: true, message: 'Ride completed!');
    } catch (e) {
      print('[FirestoreService] completeRide error: $e');
      return (success: false, message: 'Failed to complete ride.');
    }
  }

  /// Update driver's live GPS location on an in_progress ride (called every 30s)
  static Future<void> updateDriverLocation(String rideId, double lat, double lng) async {
    try {
      await _db.collection('rides').doc(rideId).update({
        'driverLat': lat,
        'driverLng': lng,
      });
    } catch (e) {
      print('[FirestoreService] updateDriverLocation error: $e');
    }
  }

  // ==========================================
  //  RIDE REQUESTS
  // ==========================================

  /// Try to join a ride. If it's instant match, accept it right away.
  static Future<({bool success, String message})> requestRide({
    required String rideId,
    int seatsRequested = 1,
  }) async {
    if (_uid == null) return (success: false, message: 'Not signed in.');

    try {
      // Get passenger name from profile
      final profile = await getUserProfile(_uid!);
      final passengerName = profile?.displayName ??
          _auth.currentUser?.email?.split('@').first ?? 'Unknown';

      // Check for existing active request — narrowed to this user only
      final existing = await _db
          .collection('ride_requests')
          .where('rideId', isEqualTo: rideId)
          .where('passengerId', isEqualTo: _uid)
          .get();

      final hasActiveRequest = existing.docs.any((doc) {
        final s = doc.data()['status'];
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
      final isInstant = rideData['instantMatch'] == true;

      if (seatsAvailable < seatsRequested) {
        return (success: false, message: 'Not enough seats available.');
      }

      if (isInstant) {
        // Instant mode enabled: use a transaction so we don't accidentally overbook seats
        final uid = _uid!;
        await _db.runTransaction((txn) async {
          final freshRide = await txn.get(_db.collection('rides').doc(rideId));
          if (!freshRide.exists) throw Exception('Ride not found.');
          final freshData = freshRide.data()!;
          final freshSeats = freshData['seatsAvailable'] as int? ?? 0;
          if (freshSeats < seatsRequested) throw Exception('Not enough seats.');

          final request = RideRequest(
            rideId: rideId,
            passengerId: uid,
            passengerName: passengerName,
            seatsRequested: seatsRequested,
            status: 'accepted',
          );
          final reqRef = _db.collection('ride_requests').doc();
          txn.set(reqRef, request.toMap());

          final newSeats = freshSeats - seatsRequested;
          final updates = <String, dynamic>{
            'seatsAvailable': newSeats,
            'passengers': FieldValue.arrayUnion([uid]),
          };
          if (newSeats <= 0) updates['status'] = 'full';
          txn.update(freshRide.reference, updates);
        });

        // Notify passenger about instant confirmation
        final origin = rideData['origin'] ?? '';
        final destination = rideData['destination'] ?? '';
        final driverName = rideData['driverName'] ?? 'Driver';
        await sendNotification(
          userId: _uid!,
          title: 'Booking Confirmed! ⚡',
          body: 'You\'re booked on $driverName\'s ride ($origin → $destination)',
          type: 'ride_accepted',
          rideId: rideId,
        );

        // Also notify the driver
        final driverId = rideData['driverId'] as String?;
        if (driverId != null) {
          await sendNotification(
            userId: driverId,
            title: 'New Passenger Booked ⚡',
            body: '$passengerName instantly booked your ride ($origin → $destination)',
            type: 'ride_request',
            rideId: rideId,
          );
        }

        return (success: true, message: 'Booked instantly! You\'re confirmed.');
      } else {
        // Normal mode: put the request into pending state so the driver can approve it later
        final request = RideRequest(
          rideId: rideId,
          passengerId: _uid!,
          passengerName: passengerName,
          seatsRequested: seatsRequested,
          status: 'pending',
        );

        await _db.collection('ride_requests').add(request.toMap());

        // Notify the driver about the new request
        final driverId = rideData['driverId'] as String?;
        if (driverId != null) {
          final origin = rideData['origin'] ?? '';
          final destination = rideData['destination'] ?? '';
          await sendNotification(
            userId: driverId,
            title: 'New Ride Request',
            body: '$passengerName wants to join your ride ($origin → $destination)',
            type: 'ride_request',
            rideId: rideId,
          );
        }

        return (success: true, message: 'Request sent! Waiting for driver approval.');
      }
    } catch (e) {
      print('[FirestoreService] requestRide error: $e');
      return (success: false, message: 'Failed to request ride.');
    }
  }

  /// Accept a request (driver action)
  static Future<({bool success, String message})> acceptRequest(String requestId) async {
    try {
      final requestDoc = await _db.collection('ride_requests').doc(requestId).get();
      if (!requestDoc.exists) return (success: false, message: 'Request not found.');

      final data = requestDoc.data()!;
      final rideId = data['rideId'] as String;
      final passengerId = data['passengerId'] as String;
      final seatsRequested = data['seatsRequested'] as int? ?? 1;

      final rideDoc = await _db.collection('rides').doc(rideId).get();
      final seatsAvailable = rideDoc.data()?['seatsAvailable'] as int? ?? 0;

      if (seatsAvailable < seatsRequested) {
        return (success: false, message: 'Not enough seats left.');
      }

      final batch = _db.batch();
      batch.update(requestDoc.reference, {'status': 'accepted'});

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

      // Notify the passenger
      final rideData = rideDoc.data();
      final origin = rideData?['origin'] ?? '';
      final destination = rideData?['destination'] ?? '';
      final driverName = rideData?['driverName'] ?? 'Driver';
      await sendNotification(
        userId: passengerId,
        title: 'Ride Accepted! 🎉',
        body: '$driverName accepted your request for $origin → $destination',
        type: 'ride_accepted',
        rideId: rideId,
      );

      return (success: true, message: 'Request accepted!');
    } catch (e) {
      print('[FirestoreService] acceptRequest error: $e');
      return (success: false, message: 'Failed to accept request.');
    }
  }

  /// Reject a request
  static Future<({bool success, String message})> rejectRequest(String requestId) async {
    try {
      final requestDoc = await _db.collection('ride_requests').doc(requestId).get();
      await _db.collection('ride_requests').doc(requestId).update({'status': 'rejected'});

      // Notify the passenger
      if (requestDoc.exists) {
        final data = requestDoc.data()!;
        final passengerId = data['passengerId'] as String;
        final rideId = data['rideId'] as String;
        final rideDoc = await _db.collection('rides').doc(rideId).get();
        final rideData = rideDoc.data();
        final origin = rideData?['origin'] ?? '';
        final destination = rideData?['destination'] ?? '';
        await sendNotification(
          userId: passengerId,
          title: 'Request Declined',
          body: 'Your request for $origin → $destination was not accepted',
          type: 'ride_rejected',
          rideId: rideId,
        );
      }

      return (success: true, message: 'Request rejected.');
    } catch (e) {
      print('[FirestoreService] rejectRequest error: $e');
      return (success: false, message: 'Failed to reject request.');
    }
  }

  /// Cancel a booking (passenger)
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
      batch.update(requestDoc.reference, {'status': 'cancelled'});

      if (prevStatus == 'accepted') {
        batch.update(_db.collection('rides').doc(rideId), {
          'seatsAvailable': FieldValue.increment(seatsRequested),
          'passengers': FieldValue.arrayRemove([passengerId]),
          'status': 'active',
        });
      }

      await batch.commit();
      return (success: true, message: 'Booking cancelled.');
    } catch (e) {
      print('[FirestoreService] cancelBooking error: $e');
      return (success: false, message: 'Failed to cancel booking.');
    }
  }

  /// Withdraw a pending ride request (passenger action — used in the cancel window)
  static Future<({bool success, String message})> cancelPendingRideRequest(String rideId) async {
    if (_uid == null) return (success: false, message: 'Not signed in.');
    try {
      final snapshot = await _db
          .collection('ride_requests')
          .where('rideId', isEqualTo: rideId)
          .where('passengerId', isEqualTo: _uid)
          .get();

      final pendingDocs = snapshot.docs.where((doc) => doc.data()['status'] == 'pending');
      if (pendingDocs.isEmpty) {
        return (success: false, message: 'No pending request found.');
      }

      final batch = _db.batch();
      for (final doc in pendingDocs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return (success: true, message: 'Request withdrawn.');
    } catch (e) {
      print('[FirestoreService] cancelPendingRideRequest error: $e');
      return (success: false, message: 'Failed to withdraw request.');
    }
  }

  /// Stream requests for a ride — single where, sort client-side
  static Stream<List<RideRequest>> getRequestsForRide(String rideId) {
    return _db
        .collection('ride_requests')
        .where('rideId', isEqualTo: rideId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => RideRequest.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((error) {
          print('[FirestoreService] getRequestsForRide error: $error');
          return <RideRequest>[];
        });
  }

  /// Stream the current user's bookings — single where, sort client-side
  static Stream<List<RideRequest>> getMyBookingsStream() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('ride_requests')
        .where('passengerId', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => RideRequest.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((error) {
          print('[FirestoreService] getMyBookingsStream error: $error');
          return <RideRequest>[];
        });
  }

  /// Stream rides the user is a passenger on (for ongoing ride detection)
  static Stream<List<Ride>> getMyActiveRidesAsPassenger() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('rides')
        .where('passengers', arrayContains: _uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Ride.fromMap(doc.data(), doc.id))
            .where((r) => r.status == 'in_progress')
            .toList())
        .handleError((error) {
          print('[FirestoreService] getMyActiveRidesAsPassenger error: $error');
          return <Ride>[];
        });
  }

  /// Get any active in-progress ride for the current user (regular or group).
  /// Listens to all three sources in parallel so that changes in any one of
  /// them (driver rides, passenger rides, group rides) trigger re-evaluation.
  /// Cached as a broadcast stream so the home screen never hits the
  /// "Stream has already been listened to" error on widget rebuild.
  static Stream<Map<String, String>?> getActiveRideInfo() {
    if (_uid == null) return Stream.value(null);
    if (_activeRideInfoStream != null && _cachedActiveRideUid == _uid) {
      return _activeRideInfoStream!;
    }
    _cachedActiveRideUid = _uid;

    late StreamController<Map<String, String>?> controller;
    StreamSubscription? sub1, sub2, sub3;

    QuerySnapshot<Map<String, dynamic>>? latestDriver;
    QuerySnapshot<Map<String, dynamic>>? latestPassenger;
    QuerySnapshot<Map<String, dynamic>>? latestGroup;

    void evaluate() {
      if (controller.isClosed) return;

      // Priority 1: regular ride as driver
      if (latestDriver != null && latestDriver!.docs.isNotEmpty) {
        final doc = latestDriver!.docs.first;
        final data = doc.data();
        controller.add({
          'rideId': doc.id,
          'type': 'ride',
          'from': data['origin'] ?? '',
          'to': data['destination'] ?? '',
          'role': 'Driver',
        });
        return;
      }

      // Priority 2: regular ride as passenger
      if (latestPassenger != null) {
        for (final doc in latestPassenger!.docs) {
          final data = doc.data();
          if (data['status'] == 'in_progress') {
            controller.add({
              'rideId': doc.id,
              'type': 'ride',
              'from': data['origin'] ?? '',
              'to': data['destination'] ?? '',
              'role': 'Passenger',
            });
            return;
          }
        }
      }

      // Priority 3: group ride as host or rider
      if (latestGroup != null) {
        for (final doc in latestGroup!.docs) {
          final data = doc.data();
          final hostId = data['hostId'] ?? '';
          final passengers = List<String>.from(data['passengers'] ?? []);
          if (hostId == _uid || passengers.contains(_uid)) {
            controller.add({
              'rideId': doc.id,
              'type': 'group_ride',
              'from': data['from'] ?? '',
              'to': data['to'] ?? '',
              'role': hostId == _uid ? 'Host' : 'Rider',
            });
            return;
          }
        }
      }

      // Nothing active
      controller.add(null);
    }

    void startListening() {
      sub1 = _db
          .collection('rides')
          .where('driverId', isEqualTo: _uid)
          .where('status', isEqualTo: 'in_progress')
          .limit(1)
          .snapshots()
          .listen((snap) {
        latestDriver = snap;
        evaluate();
      }, onError: (e) => print('[FirestoreService] getActiveRideInfo driver error: $e'));

      sub2 = _db
          .collection('rides')
          .where('passengers', arrayContains: _uid)
          .snapshots()
          .listen((snap) {
        latestPassenger = snap;
        evaluate();
      }, onError: (e) => print('[FirestoreService] getActiveRideInfo passenger error: $e'));

      sub3 = _db
          .collection('group_rides')
          .where('status', isEqualTo: 'in_progress')
          .snapshots()
          .listen((snap) {
        latestGroup = snap;
        evaluate();
      }, onError: (e) => print('[FirestoreService] getActiveRideInfo group error: $e'));
    }

    void stopListening() {
      sub1?.cancel();
      sub2?.cancel();
      sub3?.cancel();
      // Invalidate the cache so a fresh stream is created next time
      _activeRideInfoStream = null;
      _cachedActiveRideUid = null;
      if (!controller.isClosed) controller.close();
    }

    controller = StreamController<Map<String, String>?>.broadcast(
      onListen: startListening,
      onCancel: stopListening,
    );

    _activeRideInfoStream = controller.stream;
    return _activeRideInfoStream!;
  }

  // ==========================================
  //  NOTIFICATIONS
  // ==========================================

  /// Send a notification to a specific user
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? rideId,
  }) async {
    try {
      final notification = AppNotification(
        userId: userId,
        title: title,
        body: body,
        type: type,
        rideId: rideId,
      );
      await _db.collection('notifications').add(notification.toMap());
    } catch (e) {
      print('[FirestoreService] sendNotification error: $e');
    }
  }

  /// Stream recent notifications — limited to 50, server-sorted
  static Stream<List<AppNotification>> getNotificationsStream() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
              .toList();
        })
        .handleError((error) {
          print('[FirestoreService] getNotificationsStream error: $error');
        })
        .transform(
          StreamTransformer<List<AppNotification>, List<AppNotification>>.fromHandlers(
            handleData: (data, sink) => sink.add(data),
            handleError: (error, stackTrace, sink) {
              print('[FirestoreService] getNotificationsStream caught: $error');
              sink.add(<AppNotification>[]);
            },
          ),
        );
  }

  /// Stream unread notification count — cached broadcast stream
  static Stream<int> getUnreadNotificationCount() {
    if (_uid == null) return Stream.value(0);
    if (_unreadNotifStream != null && _cachedNotifUid == _uid) {
      return _unreadNotifStream!;
    }
    _cachedNotifUid = _uid;
    _unreadNotifStream = _db
        .collection('notifications')
        .where('userId', isEqualTo: _uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((error) {
          print('[FirestoreService] getUnreadCount error: $error');
          return 0;
        })
        .asBroadcastStream();
    return _unreadNotifStream!;
  }

  /// Mark a single notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({'isRead': true});
    } catch (e) {
      print('[FirestoreService] markAsRead error: $e');
    }
  }

  /// Mark all notifications as read — only fetches unread docs
  static Future<void> markAllNotificationsAsRead() async {
    if (_uid == null) return;
    try {
      final unread = await _db
          .collection('notifications')
          .where('userId', isEqualTo: _uid)
          .where('isRead', isEqualTo: false)
          .get();
      if (unread.docs.isEmpty) return;
      final ops = unread.docs
          .map((doc) => (WriteBatch b) => b.update(doc.reference, {'isRead': true}))
          .toList();
      await _commitInChunks(ops);
    } catch (e) {
      print('[FirestoreService] markAllAsRead error: $e');
    }
  }

  // ==========================================
  //  GROUP RIDES
  // ==========================================

  /// Publish a new group ride
  static Future<({bool success, String message})> publishGroupRide(GroupRide ride) async {
    try {
      // Enforce single active group per host
      final hasActive = await hasActiveGroupRide();
      if (hasActive) {
        return (success: false, message: 'You already have an active group ride. Delete it first.');
      }

      await _db.collection('group_rides').add(ride.toMap());
      return (success: true, message: 'Group ride hosted successfully!');
    } catch (e) {
      print('[FirestoreService] publishGroupRide error: $e');
      return (success: false, message: 'Failed to host group ride.');
    }
  }

  /// Fetch a single group ride by ID
  static Future<GroupRide?> getGroupRide(String groupRideId) async {
    try {
      final doc = await _db.collection('group_rides').doc(groupRideId).get();
      if (!doc.exists || doc.data() == null) return null;
      return GroupRide.fromMap(doc.data()!, doc.id);
    } catch (e) {
      return null;
    }
  }

  /// Stream all active/full group rides, sorted newest first
  static Stream<List<GroupRide>> getAvailableGroupRidesStream() {
    return _db
        .collection('group_rides')
        .where('status', whereIn: ['active', 'full'])
        .snapshots()
        .map((snapshot) {
          final cutoff = DateTime.now().subtract(const Duration(hours: 24));
          final rides = snapshot.docs
              .map((doc) => GroupRide.fromMap(doc.data(), doc.id))
              .where((r) => r.createdAt.isAfter(cutoff)) // 24h filter
              .toList();
          rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rides;
        })
        .handleError((error) {
          print('[FirestoreService] getAvailableGroupRidesStream error: $error');
          return <GroupRide>[];
        });
  }

  /// Search group rides with optional filters (client-side filtering)
  static Future<List<GroupRide>> searchGroupRides({
    String? from,
    String? to,
    DateTime? date,
    String? transport,
    String? gender,
  }) async {
    try {
      final snapshot = await _db
          .collection('group_rides')
          .where('status', whereIn: ['active', 'full'])
          .get();

      var rides = snapshot.docs
          .map((doc) => GroupRide.fromMap(doc.data(), doc.id))
          .toList();

      // Client-side filtering
      if (from != null && from.isNotEmpty) {
        final fromLower = from.toLowerCase();
        rides = rides.where((r) => r.from.toLowerCase().contains(fromLower)).toList();
      }
      if (to != null && to.isNotEmpty) {
        final toLower = to.toLowerCase();
        rides = rides.where((r) => r.to.toLowerCase().contains(toLower)).toList();
      }
      if (date != null) {
        rides = rides.where((r) =>
            r.departureTime.year == date.year &&
            r.departureTime.month == date.month &&
            r.departureTime.day == date.day).toList();
      }
      if (transport != null && transport.isNotEmpty) {
        rides = rides.where((r) => r.transport.toLowerCase() == transport.toLowerCase()).toList();
      }
      if (gender != null && gender != 'Any' && gender.isNotEmpty) {
        rides = rides.where((r) => r.gender == gender || r.gender == 'Any').toList();
      }

      rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rides;
    } catch (e) {
      print('[FirestoreService] searchGroupRides error: $e');
      return [];
    }
  }

  /// Request to join a group ride
  static Future<({bool success, String message})> requestGroupRide({
    required String groupRideId,
    int seatsRequested = 1,
  }) async {
    if (_uid == null) return (success: false, message: 'Not signed in.');

    try {
      // Check seat availability first and prevent host self-join
      final rideDoc = await _db.collection('group_rides').doc(groupRideId).get();
      if (!rideDoc.exists) return (success: false, message: 'Group ride not found.');
      final rideData = rideDoc.data()!;

      // Prevent host from joining own ride
      if (rideData['hostId'] == _uid) {
        return (success: false, message: 'You cannot join your own group ride.');
      }

      final profile = await getUserProfile(_uid!);
      final passengerName = profile?.displayName ??
          _auth.currentUser?.email?.split('@').first ?? 'Unknown';

      // Check for existing active request — narrowed to this user only
      final existing = await _db
          .collection('group_ride_requests')
          .where('groupRideId', isEqualTo: groupRideId)
          .where('passengerId', isEqualTo: _uid)
          .get();

      final hasActiveRequest = existing.docs.any((doc) {
        final s = doc.data()['status'];
        return s == 'pending' || s == 'accepted';
      });

      if (hasActiveRequest) {
        return (success: false, message: 'You already have a request for this ride.');
      }

      // Check seat availability (rideDoc/rideData already fetched above)
      final seatsAvailable = rideData['seatsAvailable'] as int? ?? 0;

      if (seatsAvailable < seatsRequested) {
        return (success: false, message: 'No seats available.');
      }

      // Create pending request only — seats deducted when host accepts
      final request = GroupRideRequest(
        groupRideId: groupRideId,
        passengerId: _uid!,
        passengerName: passengerName,
        seatsRequested: seatsRequested,
        status: 'pending',
      );
      await _db.collection('group_ride_requests').add(request.toMap());

      // Notify the host
      final hostId = rideData['hostId'] as String?;
      if (hostId != null) {
        final from = rideData['from'] ?? '';
        final to = rideData['to'] ?? '';
        await sendNotification(
          userId: hostId,
          title: 'New Group Ride Request 🚗',
          body: '$passengerName wants to join your group ride ($from → $to)',
          type: 'group_ride_request',
          rideId: groupRideId,
        );
      }

      return (success: true, message: 'Request sent to the host!');
    } catch (e) {
      print('[FirestoreService] requestGroupRide error: $e');
      return (success: false, message: 'Failed to send request.');
    }
  }

  /// Cancel a group ride (host action)
  static Future<({bool success, String message})> cancelGroupRide(String groupRideId) async {
    try {
      final batch = _db.batch();
      batch.update(_db.collection('group_rides').doc(groupRideId), {'status': 'cancelled'});

      final requests = await _db
          .collection('group_ride_requests')
          .where('groupRideId', isEqualTo: groupRideId)
          .get();

      for (final doc in requests.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'pending' || status == 'accepted') {
          batch.update(doc.reference, {'status': 'cancelled'});
        }
      }

      await batch.commit();
      return (success: true, message: 'Group ride cancelled.');
    } catch (e) {
      print('[FirestoreService] cancelGroupRide error: $e');
      return (success: false, message: 'Failed to cancel group ride.');
    }
  }

  /// Start a group ride (host action) — transitions to in_progress
  static Future<({bool success, String message})> startGroupRide(String groupRideId) async {
    try {
      final rideDoc = await _db.collection('group_rides').doc(groupRideId).get();
      if (!rideDoc.exists) return (success: false, message: 'Group ride not found.');
      final rideData = rideDoc.data()!;

      await _db.collection('group_rides').doc(groupRideId).update({
        'status': 'in_progress',
        'startedAt': Timestamp.now(),
      });

      // Reject any still-pending requests
      final pendingRequests = await _db
          .collection('group_ride_requests')
          .where('groupRideId', isEqualTo: groupRideId)
          .where('status', isEqualTo: 'pending')
          .get();
      for (final req in pendingRequests.docs) {
        await req.reference.update({'status': 'rejected'});
      }

      // Notify all passengers
      final passengers = List<String>.from(rideData['passengers'] ?? []);
      final from = rideData['from'] ?? '';
      final to = rideData['to'] ?? '';
      final hostName = rideData['hostName'] ?? 'Host';
      for (final pid in passengers) {
        await sendNotification(
          userId: pid,
          title: 'Group Ride Started! \u{1F697}',
          body: '$hostName started the ride ($from → $to)',
          type: 'group_ride_started',
          rideId: groupRideId,
        );
      }

      return (success: true, message: 'Ride started!');
    } catch (e) {
      print('[FirestoreService] startGroupRide error: $e');
      return (success: false, message: 'Failed to start ride.');
    }
  }

  /// Complete a group ride (host action) — notifies passengers, then dissolves all data
  static Future<({bool success, String message})> completeGroupRide(String groupRideId) async {
    try {
      final rideDoc = await _db.collection('group_rides').doc(groupRideId).get();
      if (!rideDoc.exists) return (success: false, message: 'Group ride not found.');
      final rideData = rideDoc.data()!;

      // Notify all passengers before dissolution
      final passengers = List<String>.from(rideData['passengers'] ?? []);
      final from = rideData['from'] ?? '';
      final to = rideData['to'] ?? '';
      for (final pid in passengers) {
        await sendNotification(
          userId: pid,
          title: 'Group Ride Ended \u2705',
          body: 'The group ride ($from → $to) is complete. Rate your experience!',
          type: 'group_ride_completed',
          rideId: groupRideId,
        );
      }

      // Dissolve all group data
      await _dissolveGroupRideData(groupRideId);

      return (success: true, message: 'Ride completed and group dissolved!');
    } catch (e) {
      print('[FirestoreService] completeGroupRide error: $e');
      return (success: false, message: 'Failed to complete ride.');
    }
  }

  /// Fully delete all data related to a group ride (ride doc, requests, GC, messages)
  static Future<void> _dissolveGroupRideData(String groupRideId) async {
    // 1. Delete all group ride requests
    final requests = await _db
        .collection('group_ride_requests')
        .where('groupRideId', isEqualTo: groupRideId)
        .get();
    for (final req in requests.docs) {
      await req.reference.delete();
    }

    // 2. Delete group chat room and its messages
    final chatRooms = await _db
        .collection('chat_rooms')
        .where('type', isEqualTo: 'group')
        .where('groupRideId', isEqualTo: groupRideId)
        .get();
    for (final room in chatRooms.docs) {
      // Delete all messages in the room
      final messages = await room.reference.collection('messages').get();
      for (final msg in messages.docs) {
        await msg.reference.delete();
      }
      await room.reference.delete();
    }

    // 3. Delete the group ride document itself
    await _db.collection('group_rides').doc(groupRideId).delete();
  }

  /// Stream group rides hosted by the current user
  static Stream<List<GroupRide>> getUserGroupRidesStream() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('group_rides')
        .where('hostId', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
          final rides = snapshot.docs
              .map((doc) => GroupRide.fromMap(doc.data(), doc.id))
              .toList();
          rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rides;
        })
        .handleError((error) {
          print('[FirestoreService] getUserGroupRidesStream error: $error');
          return <GroupRide>[];
        });
  }

  /// Check if user already has an active group ride
  static Future<bool> hasActiveGroupRide() async {
    if (_uid == null) return false;
    try {
      final snapshot = await _db
          .collection('group_rides')
          .where('hostId', isEqualTo: _uid)
          .where('status', whereIn: ['active', 'full'])
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('[FirestoreService] hasActiveGroupRide error: $e');
      return false;
    }
  }

  /// Delete a group ride completely (host action)
  static Future<({bool success, String message})> deleteGroupRide(String groupRideId) async {
    try {
      // Delete all requests
      final requests = await _db
          .collection('group_ride_requests')
          .where('groupRideId', isEqualTo: groupRideId)
          .get();

      final batch = _db.batch();
      for (final doc in requests.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_db.collection('group_rides').doc(groupRideId));
      await batch.commit();

      return (success: true, message: 'Group ride deleted.');
    } catch (e) {
      print('[FirestoreService] deleteGroupRide error: $e');
      return (success: false, message: 'Failed to delete group ride.');
    }
  }

  /// Cleanup group rides older than 24 hours — fully dissolves all data
  static Future<void> cleanupExpiredGroupRides() async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
      final expired = await _db
          .collection('group_rides')
          .where('createdAt', isLessThan: cutoff)
          .where('status', whereIn: ['active', 'full', 'in_progress'])
          .limit(10)
          .get();

      if (expired.docs.isEmpty) return;

      for (final doc in expired.docs) {
        await _dissolveGroupRideData(doc.id);
      }
    } catch (e) {
      print('[FirestoreService] cleanupExpiredGroupRides error: $e');
    }
  }

  /// Cleanup regular rides older than 24 hours — deletes ride doc and requests
  static Future<void> cleanupExpiredRides() async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
      final expired = await _db
          .collection('rides')
          .where('departureTime', isLessThan: cutoff)
          .where('status', whereIn: ['active', 'full'])
          .limit(10)
          .get();

      if (expired.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in expired.docs) {
        batch.delete(doc.reference);
        // Also delete associated ride requests
        final requests = await _db
            .collection('ride_requests')
            .where('rideId', isEqualTo: doc.id)
            .get();
        for (final req in requests.docs) {
          batch.delete(req.reference);
        }
      }
      await batch.commit();
    } catch (e) {
      print('[FirestoreService] cleanupExpiredRides error: $e');
    }
  }


  // ==========================================
  //  GROUP RIDE REQUEST MANAGEMENT (Host Actions)
  // ==========================================

  /// Stream requests for a specific group ride
  static Stream<List<GroupRideRequest>> getGroupRideRequestsStream(String groupRideId) {
    return _db
        .collection('group_ride_requests')
        .where('groupRideId', isEqualTo: groupRideId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => GroupRideRequest.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((error) {
          print('[FirestoreService] getGroupRideRequestsStream error: $error');
          return <GroupRideRequest>[];
        });
  }

  /// Check a user's request status for a specific group ride
  /// Returns: 'none', 'pending', 'accepted', 'rejected'
  static Future<String> getUserRequestStatusForRide(String groupRideId) async {
    if (_uid == null) return 'none';
    try {
      final snapshot = await _db
          .collection('group_ride_requests')
          .where('groupRideId', isEqualTo: groupRideId)
          .where('passengerId', isEqualTo: _uid)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 'none';
      return snapshot.docs.first.data()['status'] as String? ?? 'none';
    } catch (e) {
      print('[FirestoreService] getUserRequestStatusForRide error: $e');
      return 'none';
    }
  }

  /// Create or get the group chat room for a group ride
  ///
  /// Check current user's request status for a regular ride
  static Future<String> getUserRequestStatusForRegularRide(String rideId) async {
    if (_uid == null) return 'none';
    try {
      final snapshot = await _db
          .collection('ride_requests')
          .where('rideId', isEqualTo: rideId)
          .where('passengerId', isEqualTo: _uid)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 'none';
      return snapshot.docs.first.data()['status'] as String? ?? 'none';
    } catch (e) {
      print('[FirestoreService] getUserRequestStatusForRegularRide error: $e');
      return 'none';
    }
  }

  /// Create or get the group chat room for a group ride
  static Future<ChatRoom?> createOrGetGroupChat(String groupRideId) async {
    if (_uid == null) return null;
    try {
      // Check if GC already exists
      final existing = await _db
          .collection('chat_rooms')
          .where('type', isEqualTo: 'group')
          .where('groupRideId', isEqualTo: groupRideId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return ChatRoom.fromMap(existing.docs.first.data(), existing.docs.first.id);
      }

      // Fetch ride info for the title
      final rideDoc = await _db.collection('group_rides').doc(groupRideId).get();
      if (!rideDoc.exists) return null;
      final rideData = rideDoc.data()!;
      final hostId = rideData['hostId'] as String;
      final hostName = rideData['hostName'] as String? ?? 'Host';
      final from = rideData['from'] ?? '';
      final to = rideData['to'] ?? '';

      // Gather all accepted passengers
      final requestsSnapshot = await _db
          .collection('group_ride_requests')
          .where('groupRideId', isEqualTo: groupRideId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final List<String> participants = [hostId];
      final Map<String, String> names = {hostId: hostName};

      for (final doc in requestsSnapshot.docs) {
        final pid = doc.data()['passengerId'] as String;
        final pname = doc.data()['passengerName'] as String? ?? 'Unknown';
        if (!participants.contains(pid)) {
          participants.add(pid);
          names[pid] = pname;
        }
      }

      // Create the GC
      final room = ChatRoom(
        type: 'group',
        participants: participants,
        participantNames: names,
        groupRideId: groupRideId,
        groupTitle: '$from → $to',
        status: 'active',
      );

      final docRef = await _db.collection('chat_rooms').add(room.toMap());
      final newDoc = await docRef.get();
      return ChatRoom.fromMap(newDoc.data()!, newDoc.id);
    } catch (e) {
      print('[FirestoreService] createOrGetGroupChat error: $e');
      return null;
    }
  }

  /// Accept a group ride request (host action) — also adds member to group chat
  static Future<({bool success, String message})> acceptGroupRideRequest(String requestId) async {
    try {
      final requestDoc = await _db.collection('group_ride_requests').doc(requestId).get();
      if (!requestDoc.exists) return (success: false, message: 'Request not found.');

      final data = requestDoc.data()!;
      final passengerId = data['passengerId'] as String;
      final passengerName = data['passengerName'] as String? ?? 'Unknown';
      final groupRideId = data['groupRideId'] as String;
      final seatsRequested = data['seatsRequested'] as int? ?? 1;

      // Deduct seats via transaction to prevent overbooking
      await _db.runTransaction((txn) async {
        final freshRide = await txn.get(_db.collection('group_rides').doc(groupRideId));
        if (!freshRide.exists) throw Exception('Group ride not found.');
        final freshData = freshRide.data()!;
        final freshSeats = freshData['seatsAvailable'] as int? ?? 0;
        if (freshSeats < seatsRequested) throw Exception('Not enough seats available.');

        txn.update(_db.collection('group_ride_requests').doc(requestId), {'status': 'accepted'});

        final newSeats = freshSeats - seatsRequested;
        final updates = <String, dynamic>{
          'seatsAvailable': newSeats,
          'passengers': FieldValue.arrayUnion([passengerId]),
        };
        if (newSeats <= 0) updates['status'] = 'full';
        txn.update(freshRide.reference, updates);
      });

      // Notify passenger
      final rideDoc = await _db.collection('group_rides').doc(groupRideId).get();
      final rideData = rideDoc.data();
      final from = rideData?['from'] ?? '';
      final to = rideData?['to'] ?? '';
      await sendNotification(
        userId: passengerId,
        title: 'Request Approved! 🎉',
        body: 'You\'ve been accepted to the group ride ($from → $to). Tap Enter GC to join the group chat!',
        type: 'group_ride_accepted',
        rideId: groupRideId,
      );

      // Create or update group chat — add new member
      final existingGC = await _db
          .collection('chat_rooms')
          .where('type', isEqualTo: 'group')
          .where('groupRideId', isEqualTo: groupRideId)
          .limit(1)
          .get();

      if (existingGC.docs.isNotEmpty) {
        // GC exists — add the new member
        await existingGC.docs.first.reference.update({
          'participants': FieldValue.arrayUnion([passengerId]),
          'participantNames.$passengerId': passengerName,
        });
      } else {
        // First accepted member — create the GC
        await createOrGetGroupChat(groupRideId);
      }

      return (success: true, message: '$passengerName accepted!');
    } catch (e) {
      print('[FirestoreService] acceptGroupRideRequest error: $e');
      return (success: false, message: 'Failed to accept request.');
    }
  }

  /// Reject a group ride request (host action)
  static Future<({bool success, String message})> rejectGroupRideRequest(String requestId) async {
    try {
      final requestDoc = await _db.collection('group_ride_requests').doc(requestId).get();
      if (!requestDoc.exists) return (success: false, message: 'Request not found.');

      final data = requestDoc.data()!;
      final passengerId = data['passengerId'] as String;
      final groupRideId = data['groupRideId'] as String;
      final seatsRequested = data['seatsRequested'] as int? ?? 1;

      final batch = _db.batch();
      batch.update(requestDoc.reference, {'status': 'rejected'});

      // Restore seats
      batch.update(_db.collection('group_rides').doc(groupRideId), {
        'seatsAvailable': FieldValue.increment(seatsRequested),
        'passengers': FieldValue.arrayRemove([passengerId]),
        'status': 'active',
      });

      await batch.commit();

      // Notify passenger
      final rideDoc = await _db.collection('group_rides').doc(groupRideId).get();
      final rideData = rideDoc.data();
      final from = rideData?['from'] ?? '';
      final to = rideData?['to'] ?? '';
      await sendNotification(
        userId: passengerId,
        title: 'Request Declined',
        body: 'Your request for the group ride ($from → $to) was not accepted',
        type: 'group_ride_rejected',
        rideId: groupRideId,
      );

      return (success: true, message: 'Request rejected.');
    } catch (e) {
      print('[FirestoreService] rejectGroupRideRequest error: $e');
      return (success: false, message: 'Failed to reject request.');
    }
  }

  // ==========================================
  //  RATING SYSTEM
  // ==========================================

  /// Submit a rating — writes to ratings collection and atomically updates target user's profile
  static Future<({bool success, String message})> submitRating({
    required String ratedUserId,
    required int rating,
    required String rideId,
    required String rideType, // 'ride' or 'group_ride'
  }) async {
    if (_uid == null) return (success: false, message: 'Not signed in.');
    if (rating < 1 || rating > 5) return (success: false, message: 'Invalid rating.');

    try {
      // Check for duplicate
      final already = await hasUserRated(rideId: rideId, ratedUserId: ratedUserId);
      if (already) return (success: false, message: 'You already rated this user for this ride.');

      // Get rater info
      final profile = await getUserProfile(_uid!);
      final raterName = profile?.displayName ?? 'Unknown';
      final raterEmail = profile?.email ?? '';

      // Write rating document
      final ratingObj = Rating(
        raterId: _uid!,
        raterName: raterName,
        raterEmail: raterEmail,
        ratedUserId: ratedUserId,
        rating: rating,
        rideId: rideId,
        rideType: rideType,
      );
      await _db.collection('ratings').add(ratingObj.toMap());

      // Atomically update target user's averageRating & totalRatings
      final userDoc = await _db.collection('users').doc(ratedUserId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final oldTotal = (userData['totalRatings'] ?? 0) as int;
        final oldAvg = (userData['averageRating'] ?? 0.0).toDouble();
        final newTotal = oldTotal + 1;
        final newAvg = ((oldAvg * oldTotal) + rating) / newTotal;

        await _db.collection('users').doc(ratedUserId).update({
          'totalRatings': newTotal,
          'averageRating': double.parse(newAvg.toStringAsFixed(2)),
        });
      }

      return (success: true, message: 'Rating submitted!');
    } catch (e) {
      print('[FirestoreService] submitRating error: $e');
      return (success: false, message: 'Failed to submit rating.');
    }
  }

  /// Check if current user already rated a specific user for a specific ride
  static Future<bool> hasUserRated({
    required String rideId,
    required String ratedUserId,
  }) async {
    if (_uid == null) return false;
    try {
      final snapshot = await _db
          .collection('ratings')
          .where('raterId', isEqualTo: _uid)
          .where('ratedUserId', isEqualTo: ratedUserId)
          .where('rideId', isEqualTo: rideId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Mark a rating as skipped so the dialog never shows again for this ride.
  /// Writes a record with rating=0 that hasUserRated() will detect.
  static Future<void> skipRating({
    required String rideId,
    required String ratedUserId,
    required String rideType,
  }) async {
    if (_uid == null) return;
    try {
      // Only write if not already recorded
      final already = await hasUserRated(rideId: rideId, ratedUserId: ratedUserId);
      if (already) return;

      await _db.collection('ratings').add({
        'raterId': _uid,
        'raterName': 'skipped',
        'raterEmail': '',
        'ratedUserId': ratedUserId,
        'rating': 0,
        'rideId': rideId,
        'rideType': rideType,
        'createdAt': Timestamp.now(),
        'skipped': true,
      });
    } catch (e) {
      print('[FirestoreService] skipRating error: $e');
    }
  }

  /// Fetch profiles for a list of user IDs (for rating dialogs)
  static Future<List<UserProfile>> getProfiles(List<String> uids) async {
    final profiles = <UserProfile>[];
    for (final uid in uids) {
      final p = await getUserProfile(uid);
      if (p != null) profiles.add(p);
    }
    return profiles;
  }

  /// Check for any recently completed ride where the rider hasn't rated the host yet.
  /// Only riders/passengers rate — hosts just complete the ride.
  /// Returns info needed to show the rating dialog, or null if nothing pending.
  static Future<Map<String, dynamic>?> getPendingRatingInfo() async {
    if (_uid == null) return null;
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));

      // Check regular rides where user is a passenger
      // Single-field query only (no compound index needed)
      final passengerRides = await _db
          .collection('rides')
          .where('passengers', arrayContains: _uid)
          .get();

      for (final doc in passengerRides.docs) {
        final data = doc.data();
        // Filter client-side: must be completed and recent
        if (data['status'] != 'completed') continue;
        final completedAt = data['completedAt'];
        if (completedAt == null) continue;
        final completedTime = (completedAt as Timestamp).toDate();
        if (completedTime.isBefore(cutoff)) continue;

        final driverId = data['driverId'] as String;
        final rated = await hasUserRated(rideId: doc.id, ratedUserId: driverId);
        if (!rated) {
          final profile = await getUserProfile(driverId);
          if (profile != null) {
            return {
              'rideId': doc.id,
              'rideType': 'ride',
              'targetUser': profile,
              'origin': data['origin'] ?? '',
              'destination': data['destination'] ?? '',
            };
          }
        }
      }

      // Check group rides where user is a passenger (not host)
      // Single-field query only
      final groupRides = await _db
          .collection('group_rides')
          .where('passengers', arrayContains: _uid)
          .get();

      for (final doc in groupRides.docs) {
        final data = doc.data();
        // Filter client-side: must be completed and recent
        if (data['status'] != 'completed') continue;
        final completedAt = data['completedAt'];
        if (completedAt == null) continue;
        final completedTime = (completedAt as Timestamp).toDate();
        if (completedTime.isBefore(cutoff)) continue;

        final hostId = data['hostId'] as String;
        // Skip if user is the host
        if (hostId == _uid) continue;

        final rated = await hasUserRated(rideId: doc.id, ratedUserId: hostId);
        if (!rated) {
          final profile = await getUserProfile(hostId);
          if (profile != null) {
            return {
              'rideId': doc.id,
              'rideType': 'group_ride',
              'targetUser': profile,
              'origin': data['from'] ?? '',
              'destination': data['to'] ?? '',
            };
          }
        }
      }

      return null;
    } catch (e) {
      print('[FirestoreService] getPendingRatingInfo error: $e');
      return null;
    }
  }

  // ==========================================
  //  CHAT SYSTEM
  // ==========================================

  /// Create or get an existing personal chat room
  static Future<ChatRoom?> createOrGetPersonalChat(String otherUserId) async {
    if (_uid == null) return null;

    try {
      // Check if a room already exists between these two users
      final snapshot = await _db
          .collection('chat_rooms')
          .where('type', isEqualTo: 'personal')
          .where('participants', arrayContains: _uid)
          .get();

      for (final doc in snapshot.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(otherUserId)) {
          return ChatRoom.fromMap(doc.data(), doc.id);
        }
      }

      // Create new pending chat room
      final myProfile = await getUserProfile(_uid!);
      final otherProfile = await getUserProfile(otherUserId);
      final myName = myProfile?.displayName ?? _auth.currentUser?.email?.split('@').first ?? 'Unknown';
      final otherName = otherProfile?.displayName ?? 'Unknown';

      final room = ChatRoom(
        type: 'personal',
        participants: [_uid!, otherUserId],
        participantNames: {_uid!: myName, otherUserId: otherName},
        status: 'pending',
        requesterId: _uid,
      );

      final docRef = await _db.collection('chat_rooms').add(room.toMap());
      final newDoc = await docRef.get();
      return ChatRoom.fromMap(newDoc.data()!, newDoc.id);
    } catch (e) {
      print('[FirestoreService] createOrGetPersonalChat error: $e');
      return null;
    }
  }

  /// Create a group chat for a group ride

  /// Accept a chat request (recipient accepts pending personal chat)
  static Future<({bool success, String message})> acceptChatRequest(String roomId) async {
    try {
      await _db.collection('chat_rooms').doc(roomId).update({'status': 'active'});
      return (success: true, message: 'Chat request accepted!');
    } catch (e) {
      print('[FirestoreService] acceptChatRequest error: $e');
      return (success: false, message: 'Failed to accept chat request.');
    }
  }

  /// Decline a chat request
  static Future<({bool success, String message})> declineChatRequest(String roomId) async {
    try {
      await _db.collection('chat_rooms').doc(roomId).update({'status': 'closed'});
      return (success: true, message: 'Chat request declined.');
    } catch (e) {
      print('[FirestoreService] declineChatRequest error: $e');
      return (success: false, message: 'Failed to decline chat request.');
    }
  }

  /// Delete/leave a chat room (removes user from participants, closes if empty)
  static Future<void> deleteChatRoom(String roomId) async {
    if (_uid == null) return;
    try {
      final roomRef = _db.collection('chat_rooms').doc(roomId);
      final doc = await roomRef.get();
      if (!doc.exists) return;

      final participants = List<String>.from(doc.data()?['participants'] ?? []);
      participants.remove(_uid);

      if (participants.isEmpty) {
        // Last person — close the room
        await roomRef.update({'status': 'closed'});
      } else {
        // Remove self from participants
        await roomRef.update({
          'participants': FieldValue.arrayRemove([_uid]),
          'participantNames.$_uid': FieldValue.delete(),
        });
      }
    } catch (e) {
      print('[FirestoreService] deleteChatRoom error: $e');
    }
  }

  /// Send a message in a chat room
  static Future<bool> sendMessage(String roomId, String text) async {
    if (_uid == null || text.trim().isEmpty) return false;

    try {
      final profile = await getUserProfile(_uid!);
      final senderName = profile?.displayName ?? _auth.currentUser?.email?.split('@').first ?? 'Unknown';

      final message = ChatMessage(
        senderId: _uid!,
        senderName: senderName,
        text: text.trim(),
        status: 'sent',
      );

      await _db.collection('chat_rooms').doc(roomId).collection('messages').add(message.toMap());

      // Update room metadata
      await _db.collection('chat_rooms').doc(roomId).update({
        'lastMessage': text.trim(),
        'lastMessageTime': Timestamp.now(),
      });

      // Mark messages from other users as 'delivered' when sender opens the chat
      final undelivered = await _db
          .collection('chat_rooms').doc(roomId).collection('messages')
          .where('senderId', isNotEqualTo: _uid)
          .where('status', isEqualTo: 'sent')
          .get();

      final batch = _db.batch();
      for (final doc in undelivered.docs) {
        batch.update(doc.reference, {'status': 'delivered'});
      }
      await batch.commit();

      return true;
    } catch (e) {
      print('[FirestoreService] sendMessage error: $e');
      return false;
    }
  }

  /// Stream messages in a chat room (latest 100 for performance)
  static Stream<List<ChatMessage>> getMessagesStream(String roomId) {
    return _db
        .collection('chat_rooms').doc(roomId).collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
            .toList())
        .handleError((error) {
          print('[FirestoreService] getMessagesStream error: $error');
          return <ChatMessage>[];
        });
  }



  /// Mark all messages from others as 'delivered' when entering a chat
  static Future<void> markMessagesDelivered(String roomId) async {
    if (_uid == null) return;
    try {
      final msgs = await _db
          .collection('chat_rooms').doc(roomId).collection('messages')
          .where('status', isEqualTo: 'sent')
          .get();

      final ops = <void Function(WriteBatch)>[];
      for (final doc in msgs.docs) {
        if (doc.data()['senderId'] != _uid) {
          ops.add((b) => b.update(doc.reference, {'status': 'delivered'}));
        }
      }
      if (ops.isNotEmpty) await _commitInChunks(ops);
    } catch (e) {
      print('[FirestoreService] markMessagesDelivered error: $e');
    }
  }

  /// Mark unseen messages as 'seen' — only fetches messages needing update
  static Future<void> markMessagesSeen(String roomId) async {
    if (_uid == null) return;
    try {
      // Fetch only messages with status 'sent' or 'delivered' (not ALL messages)
      final sent = await _db
          .collection('chat_rooms').doc(roomId).collection('messages')
          .where('status', isEqualTo: 'sent')
          .limit(100)
          .get();
      final delivered = await _db
          .collection('chat_rooms').doc(roomId).collection('messages')
          .where('status', isEqualTo: 'delivered')
          .limit(100)
          .get();

      final ops = <void Function(WriteBatch)>[];
      for (final doc in [...sent.docs, ...delivered.docs]) {
        if (doc.data()['senderId'] != _uid) {
          ops.add((b) => b.update(doc.reference, {'status': 'seen'}));
        }
      }

      // Always update lastReadBy for the current user
      ops.add((b) => b.update(_db.collection('chat_rooms').doc(roomId), {
        'lastReadBy.$_uid': Timestamp.now(),
      }));

      await _commitInChunks(ops);
    } catch (e) {
      print('[FirestoreService] markMessagesSeen error: $e');
    }
  }

  /// Stream all chat rooms for the current user (filtered client-side for non-expired)
  static Stream<List<ChatRoom>> getChatRoomsStream() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('chat_rooms')
        .where('participants', arrayContains: _uid)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final rooms = snapshot.docs
              .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
              .where((r) => r.status != 'closed' && !r.isExpired)
              .toList();
          rooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          return rooms;
        })
        .handleError((error) {
          print('[FirestoreService] getChatRoomsStream error: $error');
          return <ChatRoom>[];
        });
  }

  /// Get count of unread chat rooms
  /// Unread chat count — cached broadcast stream
  static Stream<int> getUnreadChatCount() {
    if (_uid == null) return Stream.value(0);
    if (_unreadChatStream != null && _cachedChatUid == _uid) {
      return _unreadChatStream!;
    }
    _cachedChatUid = _uid;
    _unreadChatStream = _db
        .collection('chat_rooms')
        .where('participants', arrayContains: _uid)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          int count = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'] as String? ?? '';
            final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate() ?? now;
            if (status == 'closed' || now.isAfter(expiresAt)) continue;

            final rawLastRead = data['lastReadBy'] as Map<String, dynamic>? ?? {};
            final lastRead = (rawLastRead[_uid] as Timestamp?)?.toDate();
            final lastMsgTime = (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final lastMsg = data['lastMessage'] as String? ?? '';

            if (lastMsg.isNotEmpty && (lastRead == null || lastMsgTime.isAfter(lastRead))) {
              count++;
            }
          }
          return count;
        })
        .handleError((error) {
          print('[FirestoreService] getUnreadChatCount error: $error');
          return 0;
        })
        .asBroadcastStream();
    return _unreadChatStream!;
  }

  /// Delete expired chat rooms — limited to 20 per run to avoid heavy startup


  // ==========================================
  //  7-DAY GLOBAL CLEANUP
  //  Deletes ALL old data regardless of user,
  //  keeping the database lean.
  // ==========================================

  /// Master cleanup — call once on app start to purge all stale data (> 7 days)
  static Future<void> cleanupAllOldData() async {
    // Run all cleanups concurrently for speed
    await Future.wait([
      cleanupOldNotifications(),
      cleanupOldRides(),
      cleanupOldRideRequests(),
      cleanupOldGroupRides(),
      cleanupOldGroupRideRequests(),
      cleanupOldChatRooms(),
    ]);
  }

  /// Cleanup old notifications (> 7 days) for ALL users
  static Future<void> cleanupOldNotifications() async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
      final old = await _db
          .collection('notifications')
          .where('createdAt', isLessThan: cutoff)
          .limit(200)
          .get();
      if (old.docs.isEmpty) return;
      final ops = old.docs
          .map((doc) => (WriteBatch b) => b.delete(doc.reference))
          .toList();
      await _commitInChunks(ops);
    } catch (e) {
      print('[FirestoreService] cleanupOldNotifications error: $e');
    }
  }

  /// Cleanup old rides (> 7 days) regardless of status, plus their requests
  static Future<void> cleanupOldRides() async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
      final old = await _db
          .collection('rides')
          .where('createdAt', isLessThan: cutoff)
          .limit(50)
          .get();
      if (old.docs.isEmpty) return;

      for (final doc in old.docs) {
        final ops = <void Function(WriteBatch)>[];
        // Delete associated ride requests
        final requests = await _db
            .collection('ride_requests')
            .where('rideId', isEqualTo: doc.id)
            .get();
        for (final req in requests.docs) {
          ops.add((b) => b.delete(req.reference));
        }
        ops.add((b) => b.delete(doc.reference));
        await _commitInChunks(ops);
      }
    } catch (e) {
      print('[FirestoreService] cleanupOldRides error: $e');
    }
  }

  /// Cleanup orphaned ride requests (> 7 days) that aren't tied to any ride
  static Future<void> cleanupOldRideRequests() async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
      final old = await _db
          .collection('ride_requests')
          .where('createdAt', isLessThan: cutoff)
          .limit(200)
          .get();
      if (old.docs.isEmpty) return;
      final ops = old.docs
          .map((doc) => (WriteBatch b) => b.delete(doc.reference))
          .toList();
      await _commitInChunks(ops);
    } catch (e) {
      print('[FirestoreService] cleanupOldRideRequests error: $e');
    }
  }

  /// Cleanup old group rides (> 7 days) regardless of status, plus their data
  static Future<void> cleanupOldGroupRides() async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
      final old = await _db
          .collection('group_rides')
          .where('createdAt', isLessThan: cutoff)
          .limit(20)
          .get();
      if (old.docs.isEmpty) return;

      for (final doc in old.docs) {
        await _dissolveGroupRideData(doc.id);
      }
    } catch (e) {
      print('[FirestoreService] cleanupOldGroupRides error: $e');
    }
  }

  /// Cleanup orphaned group ride requests (> 7 days)
  static Future<void> cleanupOldGroupRideRequests() async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
      final old = await _db
          .collection('group_ride_requests')
          .where('createdAt', isLessThan: cutoff)
          .limit(200)
          .get();
      if (old.docs.isEmpty) return;
      final ops = old.docs
          .map((doc) => (WriteBatch b) => b.delete(doc.reference))
          .toList();
      await _commitInChunks(ops);
    } catch (e) {
      print('[FirestoreService] cleanupOldGroupRideRequests error: $e');
    }
  }

  /// Cleanup old chat rooms (> 7 days) and their messages
  static Future<void> cleanupOldChatRooms() async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
      final old = await _db
          .collection('chat_rooms')
          .where('createdAt', isLessThan: cutoff)
          .limit(20)
          .get();
      if (old.docs.isEmpty) return;

      for (final doc in old.docs) {
        final messages = await doc.reference.collection('messages').limit(500).get();
        final ops = <void Function(WriteBatch)>[];
        for (final msg in messages.docs) {
          ops.add((b) => b.delete(msg.reference));
        }
        ops.add((b) => b.delete(doc.reference));
        await _commitInChunks(ops);
      }
    } catch (e) {
      print('[FirestoreService] cleanupOldChatRooms error: $e');
    }
  }

  // ==========================================
  //  RIDE GROUPS (separate from group rides)
  // ==========================================

  /// Stream a single group by ID
  static Stream<RideGroup?> getGroupStream(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return RideGroup.fromMap(doc.data()!, doc.id);
    }).handleError((error) {
      print('[FirestoreService] getGroupStream error: $error');
      return null;
    });
  }

  /// Stream all active groups (not dissolved)
  static Stream<List<RideGroup>> getActiveGroupsStream() {
    return _db
        .collection('groups')
        .where('status', whereIn: ['active', 'ride_started'])
        .snapshots()
        .map((snapshot) {
          final groups = snapshot.docs
              .map((doc) => RideGroup.fromMap(doc.data(), doc.id))
              .toList();
          groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return groups;
        })
        .handleError((error) {
          print('[FirestoreService] getActiveGroupsStream error: $error');
          return <RideGroup>[];
        });
  }


  /// Leave a group (non-creator only)
  static Future<({bool success, String message})> leaveGroup(String groupId) async {
    if (_uid == null) return (success: false, message: 'Not signed in.');
    try {
      final doc = await _db.collection('groups').doc(groupId).get();
      if (!doc.exists) return (success: false, message: 'Group not found.');
      final data = doc.data()!;
      if (data['creatorId'] == _uid) {
        return (success: false, message: 'Admin cannot leave. Dissolve the group instead.');
      }
      await _db.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([_uid]),
      });
      return (success: true, message: 'You left the group.');
    } catch (e) {
      print('[FirestoreService] leaveGroup error: $e');
      return (success: false, message: 'Failed to leave group.');
    }
  }

  /// Leave a group chat room (chat_rooms collection)
  static Future<({bool success, String message})> leaveChatRoom(String roomId) async {
    if (_uid == null) return (success: false, message: 'Not signed in.');
    try {
      final doc = await _db.collection('chat_rooms').doc(roomId).get();
      if (!doc.exists) return (success: false, message: 'Chat room not found.');
      final data = doc.data()!;
      if (data['requesterId'] == _uid) {
        return (success: false, message: 'Admin cannot leave the group.');
      }

      // Get the user's display name for the system message
      final names = Map<String, dynamic>.from(data['participantNames'] ?? {});
      final userName = names[_uid] ?? 'A member';

      // Send system message BEFORE removing
      await _db.collection('chat_rooms').doc(roomId).collection('messages').add({
        'senderId': 'system',
        'senderName': '',
        'text': '$userName left the group',
        'status': 'sent',
        'createdAt': Timestamp.now(),
      });

      // Remove from participants
      await _db.collection('chat_rooms').doc(roomId).update({
        'participants': FieldValue.arrayRemove([_uid]),
        'participantNames.$_uid': FieldValue.delete(),
        'lastMessage': '$userName left the group',
        'lastMessageTime': Timestamp.now(),
      });

      // Also remove from linked groups collection so they need to re-request
      final groupRideId = data['groupRideId'] as String?;
      if (groupRideId != null) {
        // Restore seat via transaction to prevent race conditions
        try {
          await _db.runTransaction((txn) async {
            final rideRef = _db.collection('group_rides').doc(groupRideId);
            final rideSnap = await txn.get(rideRef);
            if (rideSnap.exists) {
              final rideData = rideSnap.data()!;
              final currentSeats = rideData['seatsAvailable'] as int? ?? 0;
              final updates = <String, dynamic>{
                'seatsAvailable': currentSeats + 1,
                'passengers': FieldValue.arrayRemove([_uid]),
              };
              // If ride was full, set back to active
              if (rideData['status'] == 'full') {
                updates['status'] = 'active';
              }
              txn.update(rideRef, updates);
            }
          });
        } catch (_) {}

        try {
          await _db.collection('groups').doc(groupRideId).update({
            'members': FieldValue.arrayRemove([_uid]),
          });
        } catch (_) {}

        // Delete the user's ride request so they must re-request
        try {
          final reqSnap = await _db
              .collection('group_ride_requests')
              .where('groupRideId', isEqualTo: groupRideId)
              .where('passengerId', isEqualTo: _uid)
              .get();
          for (final reqDoc in reqSnap.docs) {
            await reqDoc.reference.delete();
          }
        } catch (_) {}
      }

      return (success: true, message: 'You left the group.');
    } catch (e) {
      print('[FirestoreService] leaveChatRoom error: $e');
      return (success: false, message: 'Failed to leave group.');
    }
  }

  /// Kick a member from a group chat room (admin only)
  static Future<({bool success, String message})> kickMemberFromChatRoom(
      String roomId, String targetUid, String targetName) async {
    if (_uid == null) return (success: false, message: 'Not signed in.');
    try {
      final doc = await _db.collection('chat_rooms').doc(roomId).get();
      if (!doc.exists) return (success: false, message: 'Chat room not found.');
      final data = doc.data()!;

      // Only the creator/requester can kick
      final creatorId = data['requesterId'] ?? (data['participants'] as List?)?.first;
      if (_uid != creatorId) {
        return (success: false, message: 'Only the admin can remove members.');
      }

      if (targetUid == _uid) {
        return (success: false, message: 'You cannot remove yourself.');
      }

      // Remove from participants and participantNames
      await _db.collection('chat_rooms').doc(roomId).update({
        'participants': FieldValue.arrayRemove([targetUid]),
        'participantNames.$targetUid': FieldValue.delete(),
        'lastMessage': '$targetName was removed',
        'lastMessageTime': Timestamp.now(),
      });

      // Send system message AFTER removing
      await _db.collection('chat_rooms').doc(roomId).collection('messages').add({
        'senderId': 'system',
        'senderName': '',
        'text': '$targetName was removed from the group',
        'status': 'sent',
        'createdAt': Timestamp.now(),
      });

      // Also remove from linked groups collection
      final groupRideId = data['groupRideId'] as String?;
      if (groupRideId != null) {
        // Restore seat via transaction to prevent race conditions
        try {
          await _db.runTransaction((txn) async {
            final rideRef = _db.collection('group_rides').doc(groupRideId);
            final rideSnap = await txn.get(rideRef);
            if (rideSnap.exists) {
              final rideData = rideSnap.data()!;
              final currentSeats = rideData['seatsAvailable'] as int? ?? 0;
              final updates = <String, dynamic>{
                'seatsAvailable': currentSeats + 1,
                'passengers': FieldValue.arrayRemove([targetUid]),
              };
              if (rideData['status'] == 'full') {
                updates['status'] = 'active';
              }
              txn.update(rideRef, updates);
            }
          });
        } catch (_) {}

        try {
          await _db.collection('groups').doc(groupRideId).update({
            'members': FieldValue.arrayRemove([targetUid]),
          });
        } catch (_) {}

        // Delete the kicked user's ride request so they must re-request
        try {
          final reqSnap = await _db
              .collection('group_ride_requests')
              .where('groupRideId', isEqualTo: groupRideId)
              .where('passengerId', isEqualTo: targetUid)
              .get();
          for (final reqDoc in reqSnap.docs) {
            await reqDoc.reference.delete();
          }
        } catch (_) {}
      }

      // Notify the kicked member
      await sendNotification(
        userId: targetUid,
        title: 'Removed from Group',
        body: 'You have been removed from the group by the admin.',
        type: 'group_kicked',
      );

      return (success: true, message: '$targetName has been removed.');
    } catch (e) {
      print('[FirestoreService] kickMemberFromChatRoom error: $e');
      return (success: false, message: 'Failed to remove member.');
    }
  }

  /// Create a new group
  static Future<({bool success, String message})> createGroup(String name) async {
    if (_uid == null) return (success: false, message: 'Not signed in.');
    try {
      final profile = await getUserProfile(_uid!);
      final displayName = profile?.displayName ??
          _auth.currentUser?.email?.split('@').first ?? 'Unknown';

      final group = RideGroup(
        name: name,
        creatorId: _uid!,
        creatorName: displayName,
        members: [_uid!],
        status: 'active',
      );
      await _db.collection('groups').add(group.toMap());
      return (success: true, message: 'Group created successfully!');
    } catch (e) {
      print('[FirestoreService] createGroup error: $e');
      return (success: false, message: 'Failed to create group.');
    }
  }

  /// Request to join a group
  static Future<({bool success, String message})> requestJoinGroup(String groupId) async {
    if (_uid == null) return (success: false, message: 'Not signed in.');
    try {
      final groupDoc = await _db.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return (success: false, message: 'Group not found.');
      final group = RideGroup.fromMap(groupDoc.data()!, groupDoc.id);
      if (group.creatorId == _uid) return (success: false, message: 'You are the admin.');
      if (group.members.contains(_uid)) return (success: false, message: 'Already a member.');
      if (group.isFull) return (success: false, message: 'Group is full.');

      final profile = await getUserProfile(_uid!);
      final name = profile?.displayName ?? 'Unknown';
      await _db.collection('groups').doc(groupId).collection('join_requests').add({
        'userId': _uid,
        'userName': name,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      await sendNotification(
        userId: group.creatorId,
        title: 'New Join Request',
        body: '$name wants to join your group "${group.name}"',
        type: 'group_join_request',
      );
      return (success: true, message: 'Request sent!');
    } catch (e) {
      print('[FirestoreService] requestJoinGroup error: $e');
      return (success: false, message: 'Failed to send request.');
    }
  }

  /// Stream join requests for a group
  static Stream<List<Map<String, dynamic>>> getGroupJoinRequests(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('join_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList())
        .handleError((error) {
          print('[FirestoreService] getGroupJoinRequests error: $error');
          return <Map<String, dynamic>>[];
        });
  }

  /// Approve a join request
  static Future<({bool success, String message})> approveJoinRequest(
      String groupId, String userId) async {
    try {
      // Find the request doc
      final requests = await _db
          .collection('groups')
          .doc(groupId)
          .collection('join_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (requests.docs.isEmpty) return (success: false, message: 'Request not found.');

      final batch = _db.batch();
      batch.update(requests.docs.first.reference, {'status': 'approved'});
      batch.update(_db.collection('groups').doc(groupId), {
        'members': FieldValue.arrayUnion([userId]),
      });
      await batch.commit();

      await sendNotification(
        userId: userId,
        title: 'Request Approved ✅',
        body: 'You have been added to the group!',
        type: 'group_join_approved',
      );
      return (success: true, message: 'Member added!');
    } catch (e) {
      print('[FirestoreService] approveJoinRequest error: $e');
      return (success: false, message: 'Failed to approve.');
    }
  }

  /// Reject a join request
  static Future<({bool success, String message})> rejectJoinRequest(
      String groupId, String userId, String groupName) async {
    try {
      final requests = await _db
          .collection('groups')
          .doc(groupId)
          .collection('join_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (requests.docs.isEmpty) return (success: false, message: 'Request not found.');

      await requests.docs.first.reference.update({'status': 'rejected'});

      await sendNotification(
        userId: userId,
        title: 'Request Declined',
        body: 'Your request to join "$groupName" was not accepted.',
        type: 'group_join_rejected',
      );
      return (success: true, message: 'Request rejected.');
    } catch (e) {
      print('[FirestoreService] rejectJoinRequest error: $e');
      return (success: false, message: 'Failed to reject.');
    }
  }

  /// End a group ride (dissolve)
  static Future<({bool success, String message})> endGroupRide(String groupId) async {
    try {
      await _db.collection('groups').doc(groupId).update({
        'status': 'dissolved',
      });
      return (success: true, message: 'Group ride ended.');
    } catch (e) {
      print('[FirestoreService] endGroupRide error: $e');
      return (success: false, message: 'Failed to end group ride.');
    }
  }

}

/// Helper class for profile caching
class _CachedProfile {
  final UserProfile profile;
  final DateTime fetchedAt;
  _CachedProfile(this.profile, this.fetchedAt);
}
