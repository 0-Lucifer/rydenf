import 'package:cloud_firestore/cloud_firestore.dart';

class RideGroup {
  final String? id;
  final String name;           // destination name
  final String creatorId;
  final String creatorName;
  final List<String> members;  // UIDs, max 3
  final String status;         // active, ride_started, dissolved
  final DateTime createdAt;
  final DateTime? rideStartedAt;

  RideGroup({
    this.id,
    required this.name,
    required this.creatorId,
    required this.creatorName,
    this.members = const [],
    this.status = 'active',
    DateTime? createdAt,
    this.rideStartedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'name': name,
    'creatorId': creatorId,
    'creatorName': creatorName,
    'members': members,
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt),
    'rideStartedAt': rideStartedAt != null ? Timestamp.fromDate(rideStartedAt!) : null,
  };

  factory RideGroup.fromMap(Map<String, dynamic> map, String docId) {
    return RideGroup(
      id: docId,
      name: map['name'] ?? '',
      creatorId: map['creatorId'] ?? '',
      creatorName: map['creatorName'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      status: map['status'] ?? 'active',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rideStartedAt: (map['rideStartedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isFull => members.length >= 3;
  bool get isActive => status == 'active' || status == 'ride_started';
  bool get isRideStarted => status == 'ride_started';
  bool get isDissolved => status == 'dissolved';
}
