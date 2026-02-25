import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String? id;
  final String raterId;
  final String raterName;
  final String raterEmail;
  final String ratedUserId;
  final int rating; // 1-5
  final String rideId;
  final String rideType; // 'ride' or 'group_ride'
  final DateTime createdAt;

  Rating({
    this.id,
    required this.raterId,
    required this.raterName,
    required this.raterEmail,
    required this.ratedUserId,
    required this.rating,
    required this.rideId,
    required this.rideType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'raterId': raterId,
    'raterName': raterName,
    'raterEmail': raterEmail,
    'ratedUserId': ratedUserId,
    'rating': rating,
    'rideId': rideId,
    'rideType': rideType,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory Rating.fromMap(Map<String, dynamic> map, String docId) {
    return Rating(
      id: docId,
      raterId: map['raterId'] ?? '',
      raterName: map['raterName'] ?? '',
      raterEmail: map['raterEmail'] ?? '',
      ratedUserId: map['ratedUserId'] ?? '',
      rating: map['rating'] ?? 0,
      rideId: map['rideId'] ?? '',
      rideType: map['rideType'] ?? 'ride',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
