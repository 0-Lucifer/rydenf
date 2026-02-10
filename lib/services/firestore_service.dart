import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';
import '../models/notification_model.dart';
import '../models/rating_model.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  // ═══════════════════════════════════════════════════════
  //  USER PROFILE
  // ═══════════════════════════════════════════════════════

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
    return _db.collection('users').doc(_uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromMap(doc.data()!);
    }).handleError((error) {
      print('[FirestoreService] getUserProfileStream error: $error');
      return null;
    });
  }

  static Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromMap(doc.data()!);
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

  // ═══════════════════════════════════════════════════════
  //  RIDES
  // ═══════════════════════════════════════════════════════

  static Future<({bool success, String message})> publishRide(Ride ride) async {
    try {
      await _db.collection('rides').add(ride.toMap());
      return (success: true, message: 'Ride published successfully!');
    } catch (e) {
      print('[FirestoreService] publishRide error: $e');
      return (success: false, message: 'Failed to publish ride.');
    }
  }

  /// Stream all active rides — no compound query, filter + sort client-side
  static Stream<List<Ride>> getAvailableRidesStream() {
    return _db
        .collection('rides')
        .where('status', whereIn: ['active', 'full'])
        .snapshots()
        .map((snapshot) {
          final rides = snapshot.docs
              .map((doc) => Ride.fromMap(doc.data(), doc.id))
              .toList();
          rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rides;
        })
        .handleError((error) {
          print('[FirestoreService] getAvailableRidesStream error: $error');
          return <Ride>[];
        });
  }

  /// Stream rides the current user created — single where, sort client-side
  static Stream<List<Ride>> getUserRidesStream() {
    if (_uid == null) return Stream.value([]);
    return _db
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
        });
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

  // ═══════════════════════════════════════════════════════
  //  RIDE REQUESTS
  // ═══════════════════════════════════════════════════════

  /// Request a seat — auto-accepted if instant booking, pending otherwise
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

      // Check for existing active request — single where, filter client-side
      final existing = await _db
          .collection('ride_requests')
          .where('rideId', isEqualTo: rideId)
          .get();

      final hasActiveRequest = existing.docs.any((doc) {
        final d = doc.data();
        return d['passengerId'] == _uid &&
            (d['status'] == 'pending' || d['status'] == 'accepted');
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
        // ── INSTANT BOOKING: auto-accept ──
        final batch = _db.batch();

        final request = RideRequest(
          rideId: rideId,
          passengerId: _uid!,
          passengerName: passengerName,
          seatsRequested: seatsRequested,
          status: 'accepted',
        );
        final reqRef = _db.collection('ride_requests').doc();
        batch.set(reqRef, request.toMap());

        final newSeats = seatsAvailable - seatsRequested;
        final updates = <String, dynamic>{
          'seatsAvailable': newSeats,
          'passengers': FieldValue.arrayUnion([_uid]),
        };
        if (newSeats <= 0) updates['status'] = 'full';
        batch.update(_db.collection('rides').doc(rideId), updates);

        await batch.commit();

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
        // ── MANUAL APPROVAL: pending request ──
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

  // ═══════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ═══════════════════════════════════════════════════════

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

  /// Stream all notifications for the current user
  static Stream<List<AppNotification>> getNotificationsStream() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((error) {
          print('[FirestoreService] getNotificationsStream error: $error');
          return <AppNotification>[];
        });
  }

  /// Stream unread notification count
  static Stream<int> getUnreadNotificationCount() {
    if (_uid == null) return Stream.value(0);
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .where((doc) => doc.data()['isRead'] != true)
              .length;
        })
        .handleError((error) {
          print('[FirestoreService] getUnreadCount error: $error');
          return 0;
        });
  }

  /// Mark a single notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({'isRead': true});
    } catch (e) {
      print('[FirestoreService] markAsRead error: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllNotificationsAsRead() async {
    if (_uid == null) return;
    try {
      final unread = await _db
          .collection('notifications')
          .where('userId', isEqualTo: _uid)
          .get();
      final batch = _db.batch();
      for (final doc in unread.docs) {
        if (doc.data()['isRead'] != true) {
          batch.update(doc.reference, {'isRead': true});
        }
      }
      await batch.commit();
    } catch (e) {
      print('[FirestoreService] markAllAsRead error: $e');
    }
  }

  /// Delete notifications older than 3 days to optimize storage
  static Future<void> cleanupOldNotifications() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 3));
      final old = await _db
          .collection('notifications')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
          .get();

      if (old.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in old.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('[FirestoreService] Cleaned up ${old.docs.length} old notifications');
    } catch (e) {
      print('[FirestoreService] cleanupOldNotifications error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  RATINGS
  // ═══════════════════════════════════════════════════════

  /// Submit a rating for a user after a ride
  static Future<bool> submitRating(RideRating rating) async {
    try {
      await _db.collection('ratings').add(rating.toMap());
      return true;
    } catch (e) {
      print('[FirestoreService] submitRating error: $e');
      return false;
    }
  }

  /// Stream the average rating for a user
  static Stream<double?> getAverageRating(String userId) {
    return _db
        .collection('ratings')
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      double total = 0;
      for (final doc in snapshot.docs) {
        total += (doc.data()['rating'] as num?)?.toDouble() ?? 5.0;
      }
      return total / snapshot.docs.length;
    }).handleError((error) {
      print('[FirestoreService] getAverageRating error: $error');
      return null;
    });
  }

  /// Check if current user has already rated someone for a specific ride
  static Future<bool> hasRatedForRide(String rideId, String toUserId) async {
    if (_uid == null) return true;
    try {
      final snap = await _db
          .collection('ratings')
          .where('rideId', isEqualTo: rideId)
          .get();
      return snap.docs.any((doc) {
        final d = doc.data();
        return d['fromUserId'] == _uid && d['toUserId'] == toUserId;
      });
    } catch (e) {
      print('[FirestoreService] hasRatedForRide error: $e');
      return true;
    }
  }
}
