import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String studentId;
  final String department;
  final String batch;
  final String gender;
  final String phone;
  final String photoUrl;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.studentId = '',
    this.department = '',
    this.batch = '',
    this.gender = '',
    this.phone = '',
    this.photoUrl = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'studentId': studentId,
      'department': department,
      'batch': batch,
      'gender': gender,
      'phone': phone,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      studentId: map['studentId'] ?? '',
      department: map['department'] ?? '',
      batch: map['batch'] ?? '',
      gender: map['gender'] ?? '',
      phone: map['phone'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
