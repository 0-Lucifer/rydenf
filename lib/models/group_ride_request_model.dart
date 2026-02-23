import 'package:cloud_firestore/cloud_firestore.dart';

class GroupRideRequest {
  final String? id;
  final String groupRideId;
  final String passengerId;
  final String passengerName;
  final int seatsRequested;
  final String status; // pending, accepted, rejected, cancelled
  final DateTime createdAt;

  GroupRideRequest({
    this.id,
    required this.groupRideId,
    required this.passengerId,
    this.passengerName = '',
    this.seatsRequested = 1,
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'groupRideId': groupRideId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'seatsRequested': seatsRequested,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory GroupRideRequest.fromMap(Map<String, dynamic> map, String docId) {
    return GroupRideRequest(
      id: docId,
      groupRideId: map['groupRideId'] ?? '',
      passengerId: map['passengerId'] ?? '',
      passengerName: map['passengerName'] ?? '',
      seatsRequested: map['seatsRequested'] ?? 1,
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
