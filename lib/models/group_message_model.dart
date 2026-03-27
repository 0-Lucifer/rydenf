import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMessage {
  final String? id;
  final String senderId;
  final String senderName;
  final String text;
  final List<String> seenBy;   // UIDs who have seen this message
  final DateTime createdAt;

  GroupMessage({
    this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.seenBy = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'senderName': senderName,
    'text': text,
    'seenBy': seenBy,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory GroupMessage.fromMap(Map<String, dynamic> map, String docId) {
    return GroupMessage(
      id: docId,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      seenBy: List<String>.from(map['seenBy'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
