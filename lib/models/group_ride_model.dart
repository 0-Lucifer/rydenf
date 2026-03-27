import 'package:cloud_firestore/cloud_firestore.dart';

class GroupRide {
  final String? id;
  final String hostId;
  final String hostName;
  final double hostRating;
  final bool isVerified;
  final String from;
  final String to;
  final DateTime departureTime;
  final String transport; // 'Uber/Pathao', 'CNG', 'Rickshaw'
  final String gender; // 'Any', 'Men', 'Women'
  final int seatsTotal;
  final int seatsAvailable;
  final String notes;
  final String status; // active, full, completed, cancelled
  final List<String> passengers; // accepted passenger UIDs
  final DateTime createdAt;

  // GPS coordinates (nullable for backward compat)
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
  final double? distanceKm;
  final int? durationMinutes;

  GroupRide({
    this.id,
    required this.hostId,
    this.hostName = '',
    this.hostRating = 5.0,
    this.isVerified = false,
    required this.from,
    required this.to,
    required this.departureTime,
    this.transport = 'Uber/Pathao',
    this.gender = 'Any',
    required this.seatsTotal,
    required this.seatsAvailable,
    this.notes = '',
    this.status = 'active',
    this.passengers = const [],
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.distanceKm,
    this.durationMinutes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isFull => seatsAvailable <= 0 || status == 'full';

  /// Whether this ride has GPS coordinates.
  bool get hasCoordinates =>
      fromLat != null && fromLng != null && toLat != null && toLng != null;

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'hostName': hostName,
      'hostRating': hostRating,
      'isVerified': isVerified,
      'from': from,
      'to': to,
      'departureTime': Timestamp.fromDate(departureTime),
      'transport': transport,
      'gender': gender,
      'seatsTotal': seatsTotal,
      'seatsAvailable': seatsAvailable,
      'notes': notes,
      'status': status,
      'passengers': passengers,
      'createdAt': Timestamp.fromDate(createdAt),
      if (fromLat != null) 'fromLat': fromLat,
      if (fromLng != null) 'fromLng': fromLng,
      if (toLat != null) 'toLat': toLat,
      if (toLng != null) 'toLng': toLng,
      if (distanceKm != null) 'distanceKm': distanceKm,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
    };
  }

  factory GroupRide.fromMap(Map<String, dynamic> map, String docId) {
    return GroupRide(
      id: docId,
      hostId: map['hostId'] ?? '',
      hostName: map['hostName'] ?? '',
      hostRating: (map['hostRating'] ?? 5.0).toDouble(),
      isVerified: map['isVerified'] ?? false,
      from: map['from'] ?? '',
      to: map['to'] ?? '',
      departureTime: (map['departureTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      transport: map['transport'] ?? 'Uber/Pathao',
      gender: map['gender'] ?? 'Any',
      seatsTotal: map['seatsTotal'] ?? 1,
      seatsAvailable: map['seatsAvailable'] ?? 1,
      notes: map['notes'] ?? '',
      status: map['status'] ?? 'active',
      passengers: List<String>.from(map['passengers'] ?? []),
      fromLat: (map['fromLat'] as num?)?.toDouble(),
      fromLng: (map['fromLng'] as num?)?.toDouble(),
      toLat: (map['toLat'] as num?)?.toDouble(),
      toLng: (map['toLng'] as num?)?.toDouble(),
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      durationMinutes: map['durationMinutes'] as int?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
