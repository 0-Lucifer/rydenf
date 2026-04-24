import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/group_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';


class GroupDetailScreen extends StatelessWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kText = Color(0xFF0F172A);
  static const Color kSecondary = Color(0xFF64748B);
  static const Color kGreen = Color(0xFF10B981);
  static const Color kRed = Color(0xFFFD6B6B);
  static const Color kAmber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<RideGroup?>(
        stream: FirestoreService.getGroupStream(groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimary));
          }
          final group = snapshot.data;
          if (group == null) {
            return Center(child: Text("Group not found", style: GoogleFonts.plusJakartaSans(
              fontSize: 16, color: kSecondary,
            )));
          }

          final currentUid = AuthService.currentUser?.uid;
          final isCreator = group.creatorId == currentUid;
          final isMember = group.members.contains(currentUid);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, group)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 24, 0, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildInfoCard(group),
                    const SizedBox(height: 16),
                    _buildMembersList(group),
                    if (isCreator) ...[
                      const SizedBox(height: 16),
                      _buildJoinRequests(context, group),
                    ],
                    if (group.isDissolved) ...[
                      const SizedBox(height: 20),
                      _buildDissolvedBanner(),
                    ],
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<RideGroup?>(
        stream: FirestoreService.getGroupStream(groupId),
        builder: (context, snapshot) {
          final group = snapshot.data;
          if (group == null || group.isDissolved) return const SizedBox.shrink();

          final currentUid = AuthService.currentUser?.uid;
          final isCreator = group.creatorId == currentUid;
          final isMember = group.members.contains(currentUid);

          return _buildBottomBar(context, group, isCreator, isMember);
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, RideGroup group) {
    final color = group.isDissolved
        ? const LinearGradient(colors: [Color(0xFF64748B), Color(0xFF94A3B8)])
        : group.isRideStarted
            ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)])
            : const LinearGradient(colors: [Color(0xFFFD6B6B), Color(0xFFFF8A80)]);

    return Container(
      decoration: BoxDecoration(
        gradient: color,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      group.isDissolved ? "Dissolved" : (group.isRideStarted ? "🚗 Ride Started" : "Active"),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                group.name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _headerChip(Icons.person_rounded, "by ${group.creatorName}"),
                  const SizedBox(width: 10),
                  _headerChip(Icons.people_rounded, "${group.members.length}/3"),
                  const SizedBox(width: 10),
                  _headerChip(Icons.schedule_rounded, DateFormat('MMM dd, hh:mm a').format(group.createdAt)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white,
            ), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(RideGroup group) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("GROUP INFO", style: GoogleFonts.plusJakartaSans(
            fontSize: 11, fontWeight: FontWeight.w800, color: kSecondary, letterSpacing: 1.2,
          )),
          const SizedBox(height: 14),
          _infoRow(Icons.location_on_rounded, "Destination", group.name),
          _infoRow(Icons.person_rounded, "Created by", group.creatorName),
          _infoRow(Icons.people_rounded, "Members", "${group.members.length} of 3"),
          _infoRow(Icons.schedule_rounded, "Created", DateFormat('MMM dd, yyyy • hh:mm a').format(group.createdAt)),
          if (group.rideStartedAt != null)
            _infoRow(Icons.directions_car_rounded, "Ride started", DateFormat('hh:mm a').format(group.rideStartedAt!)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kPrimary),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w600, color: kSecondary,
          )),
          const Spacer(),
          Flexible(
            child: Text(value, style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w700, color: kText,
            ), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList(RideGroup group) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, size: 18, color: kPrimary),
              const SizedBox(width: 10),
              Text("Members", style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w800, color: kText,
              )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text("${group.members.length}/3", style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w800, color: kPrimary,
                )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...group.members.map((uid) => FutureBuilder<String>(
            future: _getMemberName(uid),
            builder: (context, snap) {
              final name = snap.data ?? 'Loading...';
              final isCreator = uid == group.creatorId;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: kPrimary.withOpacity(0.08),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800, color: kPrimary, fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name, style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 14, color: kText,
                      )),
                    ),
                    if (isCreator)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kAmber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text("Creator", style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w700, color: kAmber,
                        )),
                      ),
                  ],
                ),
              );
            },
          )),
        ],
      ),
    );
  }

  Widget _buildJoinRequests(BuildContext context, RideGroup group) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_rounded, size: 18, color: kAmber),
              const SizedBox(width: 10),
              Text("Join Requests", style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w800, color: kText,
              )),
            ],
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreService.getGroupJoinRequests(groupId),
            builder: (context, snapshot) {
              final requests = snapshot.data ?? [];
              if (requests.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text("No pending requests", style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: kSecondary,
                  )),
                );
              }
              return Column(
                children: requests.map((req) {
                  final userName = req['userName'] ?? 'User';
                  final userId = req['id'] as String;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: kAmber.withOpacity(0.1),
                          child: Text(userName[0].toUpperCase(), style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800, color: kAmber, fontSize: 14,
                          )),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(userName, style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700, fontSize: 14, color: kText,
                          )),
                        ),
                        // Approve
                        GestureDetector(
                          onTap: () async {
                            final result = await FirestoreService.approveJoinRequest(groupId, userId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(result.message),
                                backgroundColor: result.success ? kGreen : kRed,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                              ));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.check_rounded, color: kGreen, size: 20),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Reject
                        GestureDetector(
                          onTap: () async {
                            await FirestoreService.rejectJoinRequest(groupId, userId, group.name);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: const Text("Request declined"),
                                backgroundColor: kSecondary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                              ));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.close_rounded, color: kRed, size: 20),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDissolvedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSecondary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSecondary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: kSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "This group has been dissolved. Chat is now inactive.",
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, RideGroup group, bool isCreator, bool isMember) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          // Chat button (members only)

          // Join button (non-members)
          if (!isMember && !group.isFull)
            Expanded(
              child: SizedBox(
                height: 52,
                child: _JoinButton(groupId: groupId),
              ),
            ),

          if (!isMember && group.isFull)
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSecondary.withOpacity(0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text("Group Full (3/3)", style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w700, color: kSecondary,
                  )),
                ),
              ),
            ),

          // Ride controls (creator only)
          if (isCreator) ...[
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (group.isRideStarted) {
                    _showEndDialog(context, group);
                  } else {
                    _showStartDialog(context, group);
                  }
                },
                icon: Icon(
                  group.isRideStarted ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
                  color: Colors.white, size: 20,
                ),
                label: Text(
                  group.isRideStarted ? "End" : "Start",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: group.isRideStarted ? kRed : kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showStartDialog(BuildContext context, RideGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Start Ride?", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(
          "All members will be notified that the ride has started.",
          style: GoogleFonts.plusJakartaSans(color: kSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: kSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await FirestoreService.startGroupRide(groupId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result.message),
                  backgroundColor: result.success ? kGreen : kRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text("Start", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEndDialog(BuildContext context, RideGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("End Ride?", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(
          "The ride will end and the group will be dissolved. Chat will become inactive.",
          style: GoogleFonts.plusJakartaSans(color: kSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: kSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await FirestoreService.endGroupRide(groupId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result.message),
                  backgroundColor: result.success ? kGreen : kRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text("End Ride", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<String> _getMemberName(String uid) async {
    final profile = await FirestoreService.getUserProfile(uid);
    return profile?.displayName ?? 'Member';
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 6))],
  );
}

// Stateful join button to manage loading state
class _JoinButton extends StatefulWidget {
  final String groupId;
  const _JoinButton({required this.groupId});

  @override
  State<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<_JoinButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _loading ? null : () async {
        setState(() => _loading = true);
        final result = await FirestoreService.requestJoinGroup(widget.groupId);
        setState(() => _loading = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.message, style: const TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: result.success ? const Color(0xFF10B981) : const Color(0xFFFD6B6B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
        }
      },
      icon: _loading
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
      label: Text(
        _loading ? "Sending..." : "Join Group",
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF59E0B),
        disabledBackgroundColor: const Color(0xFFF59E0B).withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    );
  }
}
