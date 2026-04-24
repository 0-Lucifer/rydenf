import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/group_message_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? creatorId;
  final Map<String, String>? memberNames;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.creatorId,
    this.memberNames,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _showMemberPanel = false;

  String _creatorId = '';
  Map<String, String> _members = {};

  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kText = Color(0xFF0F172A);
  static const Color kSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    if (widget.memberNames != null) _members = Map.from(widget.memberNames!);
    if (widget.creatorId != null) _creatorId = widget.creatorId!;
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('groups').doc(widget.groupId).get();
      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!;
      final memberIds = List<String>.from(data['members'] ?? []);
      final creator = data['creatorId'] as String? ?? '';
      final names = <String, String>{};
      for (final uid in memberIds) {
        final p = await FirestoreService.getUserProfile(uid);
        names[uid] = p?.displayName ?? 'Member';
      }
      if (mounted) setState(() { _creatorId = creator; _members = names; });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    await FirestoreService.sendGroupMessage(widget.groupId, text);
    setState(() => _sending = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.groupName, style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800, fontSize: 16, color: kText,
        )),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: Column(
        children: [
          // ===== TAPPABLE MEMBER BAR =====
          Material(
            color: Colors.white,
            child: InkWell(
              onTap: () => setState(() => _showMemberPanel = !_showMemberPanel),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Icon(Icons.group_rounded, color: kPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_members.length} members',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w600, color: kSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _showMemberPanel ? 'Hide' : 'View',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary,
                      ),
                    ),
                    Icon(
                      _showMemberPanel ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: kPrimary, size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===== EXPANDABLE MEMBER PANEL =====
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _showMemberPanel
                ? Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._members.entries.map((e) {
                          final uid = e.key;
                          final name = e.value;
                          final isAdmin = uid == _creatorId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isAdmin ? kPrimary.withOpacity(0.12) : const Color(0xFFE2E8F0),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12, fontWeight: FontWeight.w800,
                                      color: isAdmin ? kPrimary : kSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    uid == currentUid ? '$name (You)' : name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13, fontWeight: FontWeight.w600, color: kText,
                                    ),
                                  ),
                                ),
                                if (isAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: kPrimary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Admin', style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9, fontWeight: FontWeight.w800, color: kPrimary,
                                    )),
                                  ),
                              ],
                            ),
                          );
                        }),
                        // Leave button for non-creators
                        if (currentUid != _creatorId && _members.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: TextButton(
                              onPressed: () async {
                                final result = await FirestoreService.leaveGroup(widget.groupId);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(result.message)),
                                  );
                                  if (result.success) Navigator.pop(context);
                                }
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFFEE2E2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text('Leave Group', style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444),
                              )),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ===== MESSAGES =====
          Expanded(
            child: StreamBuilder<List<GroupMessage>>(
              stream: FirestoreService.getGroupMessagesStream(widget.groupId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                for (final msg in messages) {
                  if (msg.id != null && !msg.seenBy.contains(currentUid)) {
                    FirestoreService.markMessageSeen(widget.groupId, msg.id!);
                  }
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: kSecondary.withOpacity(0.25)),
                        const SizedBox(height: 12),
                        Text("No messages yet", style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w700, color: kSecondary,
                        )),
                        const SizedBox(height: 4),
                        Text("Say hello to the group! 👋", style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: kSecondary.withOpacity(0.6),
                        )),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == currentUid;
                    final showName = !isMe && (i == 0 || messages[i - 1].senderId != msg.senderId);
                    return _buildBubble(msg, isMe, showName);
                  },
                );
              },
            ),
          ),

          // ===== INPUT =====
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBubble(GroupMessage msg, bool isMe, bool showName) {
    final count = _members.length;
    final seenByAll = count > 0 && msg.seenBy.length >= count;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 6, left: isMe ? 60 : 0, right: isMe ? 0 : 60),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showName)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 3),
                child: Text(msg.senderName, style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary,
                )),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? kPrimary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isMe ? 0.06 : 0.03),
                    blurRadius: 8, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(msg.text, style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w500,
                    color: isMe ? Colors.white : kText, height: 1.4,
                  )),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('hh:mm a').format(msg.createdAt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: isMe ? Colors.white.withOpacity(0.6) : kSecondary.withOpacity(0.5),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          seenByAll ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 14,
                          color: seenByAll ? const Color(0xFF34D399) : Colors.white.withOpacity(0.5),
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

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.plusJakartaSans(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: kSecondary.withOpacity(0.4)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: kPrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: kPrimary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
