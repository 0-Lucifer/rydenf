import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/group_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kText = Color(0xFF0F172A);
  static const Color kSecondary = Color(0xFF64748B);
  static const Color kGreen = Color(0xFF10B981);
  static const Color kRed = Color(0xFFFD6B6B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(child: _buildHeader(context)),
          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),
                _buildCreateCard(context),
                const SizedBox(height: 28),
                _sectionTitle("Active Groups"),
                const SizedBox(height: 12),
                _buildActiveGroups(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFD6B6B), Color(0xFFFF8A80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text("Groups", style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white,
                        )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                "Group Rides",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Create or join a group to ride together",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: kRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add_rounded, color: kRed, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Create New Group", style: GoogleFonts.plusJakartaSans(
                      fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
                    )),
                    const SizedBox(height: 3),
                    Text("Up to 3 members • Auto-dissolves in 24h", style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.5),
                    )),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.3), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title, style: GoogleFonts.plusJakartaSans(
        fontSize: 18, fontWeight: FontWeight.w800, color: kText,
      )),
    );
  }

  Widget _buildActiveGroups(BuildContext context) {
    return StreamBuilder<List<RideGroup>>(
      stream: FirestoreService.getActiveGroupsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: kPrimary),
          ));
        }
        final groups = snapshot.data ?? [];
        if (groups.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              children: [
                Icon(Icons.groups_outlined, size: 48, color: kSecondary.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text("No active groups", style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w700, color: kSecondary,
                )),
                const SizedBox(height: 4),
                Text("Create one to get started!", style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: kSecondary.withOpacity(0.7),
                )),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: groups.map((group) => _groupCard(context, group)).toList(),
          ),
        );
      },
    );
  }

  Widget _groupCard(BuildContext context, RideGroup group) {
    final currentUid = AuthService.currentUser?.uid;
    final isCreator = group.creatorId == currentUid;
    final isMember = group.members.contains(currentUid);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => GroupDetailScreen(groupId: group.id!),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: group.isRideStarted ? kGreen.withOpacity(0.1) : kRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                group.isRideStarted ? Icons.directions_car_rounded : Icons.groups_rounded,
                color: group.isRideStarted ? kGreen : kRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w800, color: kText,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text("by ${group.creatorName}", style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w500, color: kSecondary,
                      )),
                      const SizedBox(width: 10),
                      Container(
                        width: 3, height: 3,
                        decoration: BoxDecoration(color: kSecondary.withOpacity(0.4), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Text("${group.members.length}/3", style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            // Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: group.isRideStarted
                        ? kGreen.withOpacity(0.1)
                        : (isMember ? kPrimary.withOpacity(0.1) : kSecondary.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    group.isRideStarted ? "Ongoing" : (isCreator ? "Creator" : (isMember ? "Member" : "Open")),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: group.isRideStarted ? kGreen : (isMember ? kPrimary : kSecondary),
                    ),
                  ),
                ),
                if (group.isRideStarted) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text("LIVE", style: GoogleFonts.plusJakartaSans(
                        fontSize: 9, fontWeight: FontWeight.w800, color: kGreen, letterSpacing: 1,
                      )),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
