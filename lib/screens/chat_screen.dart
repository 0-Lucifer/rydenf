import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_room_model.dart';
import '../models/chat_message_model.dart';
import '../services/firestore_service.dart';
import '../services/local_notification_service.dart';
import '../widgets/profile_popup.dart';

class ChatScreen extends StatefulWidget {
  final ChatRoom room;
  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;
  bool _isSending = false;

  // Optimistic messages shown instantly before Firestore confirms
  final List<ChatMessage> _optimisticMessages = [];

  // Live room data — updated in real-time so status changes reflect instantly
  late ChatRoom _liveRoom;
  StreamSubscription<ChatRoom?>? _roomSub;

  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kDark = Color(0xFF0F172A);
  static const Color kMuted = Color(0xFF64748B);
  static const Color kBg = Color(0xFFF1F5F9);
  static const Color kSurface = Colors.white;
  static const Color kBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _liveRoom = widget.room;
    WidgetsBinding.instance.addObserver(this);
    // Suppress ALL chat notifications while viewing this chat
    LocalNotificationService.instance.setActiveChatRoom(widget.room.id);
    // Mark messages as seen
    if (widget.room.id != null) {
      FirestoreService.markMessagesDelivered(widget.room.id!);
      FirestoreService.markMessagesSeen(widget.room.id!);
      // Listen for real-time room changes (e.g. status pending → active)
      _roomSub = FirestoreService.getChatRoomStream(widget.room.id!).listen((room) {
        if (room != null && mounted) {
          setState(() => _liveRoom = room);
        }
      });
    }
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    LocalNotificationService.instance.setActiveChatRoom(null);
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.room.id != null) {
      FirestoreService.markMessagesSeen(widget.room.id!);
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    HapticFeedback.lightImpact();
    _messageController.clear();

    // Optimistic: show the message immediately
    final optimistic = ChatMessage(
      id: 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _myUid ?? '',
      senderName: 'Me',
      text: text,
      createdAt: DateTime.now(),
      status: 'sending',
    );

    setState(() {
      _optimisticMessages.add(optimistic);
      _isSending = true;
    });

    // Send to Firestore in background — don't await for UI
    FirestoreService.sendMessage(widget.room.id!, text).then((_) {
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.id == optimistic.id);
          _isSending = false;
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.id == optimistic.id);
          _isSending = false;
        });
      }
    });

    // Keep focus on input for rapid typing
    _focusNode.requestFocus();
  }

  String get _chatTitle {
    if (_liveRoom.type == 'group') {
      return _liveRoom.groupTitle ?? 'Group Chat';
    }
    for (final entry in _liveRoom.participantNames.entries) {
      if (entry.key != _myUid) return entry.value;
    }
    return 'Chat';
  }

  String get _chatSubtitle {
    if (_liveRoom.type == 'group') {
      return '${_liveRoom.participants.length} members';
    }
    return 'Personal chat';
  }

  void _showGroupMembers() {
    final creatorId = _liveRoom.requesterId ?? _liveRoom.participants.first;
    final isCreator = _myUid == creatorId;
    final members = _liveRoom.participantNames.entries.toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Group Members', style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w800, color: kDark,
                )),
                const SizedBox(height: 4),
                Text('${members.length} members', style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: kMuted,
                )),
                const SizedBox(height: 16),
                ...members.map((e) {
                  final uid = e.key;
                  final name = e.value;
                  final isAdmin = uid == creatorId;
                  final isMe = uid == _myUid;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isAdmin
                              ? const Color(0xFF8B5CF6).withOpacity(0.12)
                              : const Color(0xFFE2E8F0),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w800,
                              color: isAdmin ? const Color(0xFF8B5CF6) : kMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isMe ? '$name (You)' : name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w700, color: kDark,
                            ),
                          ),
                        ),
                        if (isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Admin', style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF8B5CF6),
                            )),
                          ),
                        // Kick button — only for admin, not for self
                        if (isCreator && !isAdmin && !isMe)
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              _confirmKick(uid, name);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_remove_rounded, size: 14, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 4),
                                  Text('Remove', style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444),
                                  )),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                // Leave button for non-creators
                if (!isCreator) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        if (widget.room.id != null) {
                          final result = await FirestoreService.leaveChatRoom(widget.room.id!);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                            if (result.success) Navigator.pop(context);
                          }
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE2E2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Leave Group', style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444),
                      )),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmKick(String uid, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove $name?', style: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w800, color: kDark,
        )),
        content: Text(
          'This member will be removed from the group and a seat will open up for new requests.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, color: kMuted,
            )),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (widget.room.id != null) {
                final result = await FirestoreService.kickMemberFromChatRoom(
                  widget.room.id!, uid, name,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      backgroundColor: result.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            child: Text('Remove', style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, color: const Color(0xFFEF4444),
            )),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _liveRoom.expiresAt.difference(DateTime.now());
    final expiryText = remaining.isNegative
        ? 'Expired'
        : remaining.inHours > 0
            ? '${remaining.inHours}h ${remaining.inMinutes % 60}m left'
            : '${remaining.inMinutes}m left';

    return Scaffold(
      backgroundColor: kBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: BoxDecoration(
            color: kSurface,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kDark, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  // Avatar — tappable for profile
                  GestureDetector(
                    onTap: () {
                      // For personal chats, show the other person's profile
                      if (_liveRoom.type == 'personal') {
                        final otherId = _liveRoom.participants.firstWhere(
                          (id) => id != _myUid,
                          orElse: () => '',
                        );
                        if (otherId.isNotEmpty) showUserProfile(context, otherId);
                      }
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _liveRoom.type == 'group'
                              ? [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)]
                              : [kPrimary, const Color(0xFF60A5FA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _liveRoom.type == 'group'
                            ? const Icon(Icons.groups_rounded, color: Colors.white, size: 20)
                            : Text(
                                _chatTitle.isNotEmpty ? _chatTitle[0].toUpperCase() : '?',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_chatTitle,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: kDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: remaining.isNegative ? Colors.red : const Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              expiryText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: remaining.inHours < 2 ? Colors.redAccent : kMuted,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.circle, size: 3, color: kMuted),
                            ),
                            Text(
                              _chatSubtitle,
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: kMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_liveRoom.type == 'group')
                    GestureDetector(
                      onTap: _showGroupMembers,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_liveRoom.participants.length}',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 14, color: const Color(0xFF8B5CF6)),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF8B5CF6)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Pending banner
          if (_liveRoom.status == 'pending' && _liveRoom.requesterId == _myUid)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.withOpacity(0.08), Colors.amber.withOpacity(0.06)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Waiting for the host to accept your message request...",
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),

          // Messages — REVERSED ListView for natural bottom-anchoring
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: FirestoreService.getMessagesStream(widget.room.id!),
              builder: (context, snapshot) {
                final serverMessages = snapshot.data ?? [];

                // Merge server + optimistic (avoid duplicates)
                final allMessages = <ChatMessage>[...serverMessages];
                for (final opt in _optimisticMessages) {
                  final isDuplicate = serverMessages.any(
                    (m) => m.text == opt.text && m.senderId == opt.senderId &&
                        m.createdAt.difference(opt.createdAt).inSeconds.abs() < 5,
                  );
                  if (!isDuplicate) allMessages.add(opt);
                }

                allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

                if (allMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.chat_bubble_outline_rounded, size: 40, color: kPrimary.withOpacity(0.4)),
                        ),
                        const SizedBox(height: 16),
                        Text("Start a conversation 👋",
                            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
                        const SizedBox(height: 4),
                        Text("Messages dissolve after 24 hours",
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                  );
                }

                // Mark seen
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (widget.room.id != null) FirestoreService.markMessagesSeen(widget.room.id!);
                });

                // Reversed ListView — always stays at bottom naturally
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  physics: const BouncingScrollPhysics(),
                  cacheExtent: 500,
                  itemCount: allMessages.length,
                  itemBuilder: (context, index) {
                    // Reverse index since ListView is reversed
                    final msgIndex = allMessages.length - 1 - index;
                    final msg = allMessages[msgIndex];
                    final isMe = msg.senderId == _myUid;
                    final showName = _liveRoom.type == 'group' && !isMe;

                    // Date separator check
                    bool showDate = false;
                    if (msgIndex == 0) {
                      showDate = true;
                    } else {
                      final prev = allMessages[msgIndex - 1];
                      if (msg.createdAt.day != prev.createdAt.day) showDate = true;
                    }

                    return RepaintBoundary(
                      child: Column(
                        children: [
                          if (showDate) _buildDateSeparator(msg.createdAt),
                          _MessageBubble(
                            message: msg,
                            isMe: isMe,
                            showSenderName: showName,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input
          _buildPremiumInput(),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String text;
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      text = 'Today';
    } else {
      text = DateFormat('MMM dd, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: kDark.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(text,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 0.2)),
        ),
      ),
    );
  }

  Widget _buildPremiumInput() {
    final canSend = _liveRoom.status == 'active' ||
        (_liveRoom.status == 'pending' && _liveRoom.requesterId == _myUid);

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 8, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: kSurface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Input field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: kBorder.withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Emoji placeholder
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: IconButton(
                      icon: Icon(Icons.emoji_emotions_outlined, color: kMuted.withOpacity(0.5), size: 24),
                      onPressed: () {},
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      enabled: canSend,
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, color: kDark, height: 1.4),
                      decoration: InputDecoration(
                        hintText: canSend ? "Type a message..." : "Waiting for acceptance...",
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: kMuted.withOpacity(0.4),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      ),
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button with animation
          GestureDetector(
            onTap: canSend ? _sendMessage : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: canSend
                    ? const LinearGradient(
                        colors: [kPrimary, Color(0xFF1D6AE5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: canSend ? null : kBorder,
                borderRadius: BorderRadius.circular(16),
                boxShadow: canSend
                    ? [BoxShadow(color: kPrimary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]
                    : null,
              ),
              child: const Center(
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Premium Message Bubble ──────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showSenderName;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.showSenderName = false,
  });

  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    // System messages (leave/kick notes)
    if (message.senderId == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      );
    }

    final time = DateFormat('h:mm a').format(message.createdAt);
    final isSending = message.status == 'sending';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 6,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showSenderName)
              Padding(
                padding: const EdgeInsets.only(left: 14, bottom: 3),
                child: Text(
                  message.senderName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            AnimatedOpacity(
              opacity: isSending ? 0.6 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          colors: [kPrimary, Color(0xFF1D6AE5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMe
                          ? kPrimary.withOpacity(0.15)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: isMe ? 12 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.text,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: isMe ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: isMe ? Colors.white.withOpacity(0.55) : kMuted.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildStatusIcon(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (message.status == 'sending') {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Colors.white.withOpacity(0.5),
        ),
      );
    }
    switch (message.status) {
      case 'seen':
        return const _DoubleCheck(color: Colors.white);
      case 'delivered':
        return _DoubleCheck(color: Colors.white.withOpacity(0.55));
      case 'sent':
      default:
        return Icon(Icons.check_rounded, size: 14, color: Colors.white.withOpacity(0.55));
    }
  }
}

/// WhatsApp-style double-check mark widget
class _DoubleCheck extends StatelessWidget {
  final Color color;
  const _DoubleCheck({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 14,
      child: Stack(
        children: [
          Positioned(left: 0, child: Icon(Icons.check_rounded, size: 14, color: color)),
          Positioned(left: 6, child: Icon(Icons.check_rounded, size: 14, color: color)),
        ],
      ),
    );
  }
}
