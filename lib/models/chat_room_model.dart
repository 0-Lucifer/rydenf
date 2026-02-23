import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String? id;
  final String type; // 'personal' or 'group'
  final List<String> participants; // UIDs
  final Map<String, String> participantNames; // uid → displayName
  final String? groupRideId; // linked group ride (for group chats)
  final String? groupTitle; // e.g. "NSU → Banani"
  final String lastMessage;
  final DateTime lastMessageTime;
  final String status; // 'pending', 'active', 'closed'
  final String? requesterId; // who initiated (for pending personal chats)
  final Map<String, DateTime> lastReadBy; // uid → timestamp of last read
  final DateTime createdAt;
  final DateTime expiresAt;

  ChatRoom({
    this.id,
    required this.type,
    required this.participants,
    this.participantNames = const {},
    this.groupRideId,
    this.groupTitle,
    this.lastMessage = '',
    DateTime? lastMessageTime,
    this.status = 'pending',
    this.requesterId,
    this.lastReadBy = const {},
    DateTime? createdAt,
    DateTime? expiresAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastMessageTime = lastMessageTime ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(hours: 24));

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'participants': participants,
      'participantNames': participantNames,
      'groupRideId': groupRideId,
      'groupTitle': groupTitle,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'status': status,
      'requesterId': requesterId,
      'lastReadBy': lastReadBy.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  factory ChatRoom.fromMap(Map<String, dynamic> map, String docId) {
    // Parse lastReadBy
    final rawLastRead = map['lastReadBy'] as Map<String, dynamic>? ?? {};
    final lastReadBy = rawLastRead.map((k, v) =>
        MapEntry(k, (v as Timestamp?)?.toDate() ?? DateTime.now()));

    return ChatRoom(
      id: docId,
      type: map['type'] ?? 'personal',
      participants: List<String>.from(map['participants'] ?? []),
      participantNames: Map<String, String>.from(map['participantNames'] ?? {}),
      groupRideId: map['groupRideId'],
      groupTitle: map['groupTitle'],
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      requesterId: map['requesterId'],
      lastReadBy: lastReadBy,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 24)),
    );
  }
}
