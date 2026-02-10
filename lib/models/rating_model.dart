import 'package:cloud_firestore/cloud_firestore.dart';

class RideRating {
  final String? id;
  final String rideId;
  final String fromUserId;
  final String toUserId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  RideRating({
    this.id,
    required this.rideId,
    required this.fromUserId,
    required this.toUserId,
    required this.rating,
    this.comment = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RideRating.fromMap(Map<String, dynamic> map, String docId) {
    return RideRating(
      id: docId,
      rideId: map['rideId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      comment: map['comment'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
