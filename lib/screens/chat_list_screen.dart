import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_room_model.dart';
import '../services/firestore_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  static const Color kPrimaryBlue = Color(0xFF2E7CF6);
  static const Color kContentColor = Color(0xFF0F172A);
  static const Color kSecondaryText = Color(0xFF64748B);
  static const Color kBgColor = Color(0xFFF8FAFC);
  static const Color kBorderColor = Color(0xFFE2E8F0);
  static const Color kSuccessGreen = Color(0xFF10B981);

  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text("Messages",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 20, color: kContentColor)),
      ),
      body: StreamBuilder<List<ChatRoom>>(
        stream: FirestoreService.getChatRoomsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
          }

          final rooms = snapshot.data ?? [];

          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("No messages yet",
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
                  const SizedBox(height: 6),
                  Text("Start a conversation from a group ride",
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade400)),
                ],
              ),
            );
          }

          // Separate message requests from active chats
          final messageRequests = rooms.where((r) =>
              r.type == 'personal' &&
              r.status == 'pending' &&
              r.requesterId != _myUid
          ).toList();

          final activeChats = rooms.where((r) =>
              r.status == 'active' ||
              (r.status == 'pending' && r.requesterId == _myUid) // show sent requests too
          ).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
            physics: const BouncingScrollPhysics(),
            children: [
              // Message Requests Section
              if (messageRequests.isNotEmpty) ...[
                _buildSectionHeader("Message Requests", messageRequests.length),
                ...messageRequests.map((room) => _buildDismissible(
                  context, room,
                  child: _MessageRequestTile(room: room, myUid: _myUid ?? ''),
                )),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: kBorderColor, height: 1),
                ),
                const SizedBox(height: 16),
              ],

              // Active Chats
              if (activeChats.isNotEmpty) ...[
                _buildSectionHeader("Chats", activeChats.length),
                ...activeChats.map((room) => _buildDismissible(
                  context, room,
                  child: _ChatTile(room: room, myUid: _myUid ?? ''),
                )),
              ],

              if (messageRequests.isEmpty && activeChats.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text("All caught up!",
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade400)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: kContentColor)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: kPrimaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text("$count",
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimaryBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissible(BuildContext context, ChatRoom room, {required Widget child}) {
    return Dismissible(
      key: ValueKey(room.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          barrierColor: const Color(0xFF0F172A).withOpacity(0.5),
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            backgroundColor: Colors.white,
            contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            actionsPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFFFEE2E2), const Color(0xFFFECACA).withOpacity(0.5)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 28),
                ),
                const SizedBox(height: 20),
                Text('Delete chat?', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: kContentColor)),
                const SizedBox(height: 8),
                Text(
                  'This conversation will be removed from your list.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: kSecondaryText, height: 1.5),
                ),
                const SizedBox(height: 28),
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Keep It', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: kSecondaryText)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          child: Text('Delete', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ) ?? false;
      },
      onDismissed: (_) {
        if (room.id != null) {
          FirestoreService.deleteChatRoom(room.id!);
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 24),
      ),
      child: child,
    );
  }
}

// ─── Message Request Tile ──────────────────────────────────
class _MessageRequestTile extends StatelessWidget {
  final ChatRoom room;
  final String myUid;
  const _MessageRequestTile({required this.room, required this.myUid});

  static const Color kPrimaryBlue = Color(0xFF2E7CF6);
  static const Color kContentColor = Color(0xFF0F172A);
  static const Color kSecondaryText = Color(0xFF64748B);
  static const Color kBorderColor = Color(0xFFE2E8F0);
  static const Color kSuccessGreen = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final otherName = _getOtherName();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimaryBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: kPrimaryBlue.withOpacity(0.1),
            child: Text(
              otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: kPrimaryBlue, fontSize: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(otherName,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: kContentColor)),
                const SizedBox(height: 2),
                Text("Wants to chat with you",
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kSecondaryText, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Accept/Decline
          IconButton(
            onPressed: () async {
              await FirestoreService.declineChatRequest(room.id!);
            },
            icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 22),
            style: IconButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.1)),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              await FirestoreService.acceptChatRequest(room.id!);
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
                );
              }
            },
            icon: const Icon(Icons.check_rounded, color: kSuccessGreen, size: 22),
            style: IconButton.styleFrom(backgroundColor: kSuccessGreen.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  String _getOtherName() {
    for (final entry in room.participantNames.entries) {
      if (entry.key != myUid) return entry.value;
    }
    return 'Unknown';
  }
}

// ─── Active Chat Tile ──────────────────────────────────
class _ChatTile extends StatelessWidget {
  final ChatRoom room;
  final String myUid;
  const _ChatTile({required this.room, required this.myUid});

  static const Color kPrimaryBlue = Color(0xFF2E7CF6);
  static const Color kContentColor = Color(0xFF0F172A);
  static const Color kSecondaryText = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final isGroup = room.type == 'group';
    final title = isGroup
        ? (room.groupTitle ?? 'Group Chat')
        : _getOtherName();
    final isPending = room.status == 'pending' && room.requesterId == myUid;

    // Check if unread
    final lastRead = room.lastReadBy[myUid];
    final hasUnread = room.lastMessage.isNotEmpty &&
        (lastRead == null || room.lastMessageTime.isAfter(lastRead));

    // Time display
    final now = DateTime.now();
    final msgTime = room.lastMessageTime;
    String timeStr;
    if (msgTime.day == now.day && msgTime.month == now.month && msgTime.year == now.year) {
      timeStr = DateFormat('h:mm a').format(msgTime);
    } else {
      timeStr = DateFormat('MMM dd').format(msgTime);
    }

    // Expiry countdown
    final remaining = room.expiresAt.difference(DateTime.now());
    final expiryText = remaining.inHours > 0
        ? '${remaining.inHours}h left'
        : '${remaining.inMinutes}m left';

    return InkWell(
      onTap: () {
        if (room.status == 'active' || isPending) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: isGroup
                  ? Colors.deepPurple.withOpacity(0.1)
                  : kPrimaryBlue.withOpacity(0.1),
              child: Icon(
                isGroup ? Icons.groups_rounded : Icons.person_rounded,
                color: isGroup ? Colors.deepPurple : kPrimaryBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: hasUnread ? FontWeight.w900 : FontWeight.w700,
                                fontSize: 15,
                                color: kContentColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(timeStr,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w500,
                              color: hasUnread ? kPrimaryBlue : kSecondaryText)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isPending ? 'Request sent — waiting...' : room.lastMessage,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                              color: hasUnread ? kContentColor : kSecondaryText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: remaining.inHours < 2
                              ? Colors.redAccent.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(expiryText,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: remaining.inHours < 2 ? Colors.redAccent : kSecondaryText)),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: kPrimaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getOtherName() {
    for (final entry in room.participantNames.entries) {
      if (entry.key != myUid) return entry.value;
    }
    return 'Unknown';
  }
}
