import 'package:cloud_firestore/cloud_firestore.dart';

class RideRequest {
  final String? id;
  final String rideId;
  final String passengerId;
  final String passengerName;
  final int seatsRequested;
  final String status; // pending, accepted, rejected, cancelled
  final DateTime createdAt;

  RideRequest({
    this.id,
    required this.rideId,
    required this.passengerId,
    this.passengerName = '',
    this.seatsRequested = 1,
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'seatsRequested': seatsRequested,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RideRequest.fromMap(Map<String, dynamic> map, String docId) {
    return RideRequest(
      id: docId,
      rideId: map['rideId'] ?? '',
      passengerId: map['passengerId'] ?? '',
      passengerName: map['passengerName'] ?? '',
      seatsRequested: map['seatsRequested'] ?? 1,
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
