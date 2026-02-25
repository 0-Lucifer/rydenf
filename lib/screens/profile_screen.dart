import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_gate.dart';
import '../models/user_model.dart';
import 'edit_profile_screen.dart';
import 'my_rides_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color kPrimaryBlue = Color(0xFF2E7CF6);
  static const Color kBackgroundColor = Color(0xFFF8FAFC);
  static const Color kTextPrimary = Color(0xFF0F172A);
  static const Color kTextSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: StreamBuilder<UserProfile?>(
        stream: FirestoreService.getUserProfileStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimaryBlue),
            );
          }

          final profile = snapshot.data;
          final displayName = (profile?.displayName.isNotEmpty == true)
              ? profile!.displayName
              : (AuthService.currentUser?.email?.split('@').first ?? 'Student');
          final email = AuthService.currentUser?.email ?? '';

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Immersive Gradient header
              SliverToBoxAdapter(
                child: _buildGradientHeader(displayName, email, profile),
              ),

              // Content Area
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 24, 0, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStudentInfoCard(profile),
                    const SizedBox(height: 24),
                    _buildActionsSection(profile),
                    const SizedBox(height: 24),
                    _buildSafetySection(),
                    const SizedBox(height: 12),
                    _buildLogoutButton(),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGradientHeader(String displayName, String email, UserProfile? profile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E7CF6), Color(0xFF4AC7FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          // Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "My Profile",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
              _buildEditBtn(profile),
            ],
          ),
          const SizedBox(height: 32),

          // Avatar & Verification Stack
          _buildAvatarStack(displayName),
          const SizedBox(height: 28),

          // User Identity with Premium Typography
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFDFF6FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: Text(
              displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.1,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.12),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFCDEBFF).withOpacity(0.85),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 12),

          // Rating display
          if (profile != null && profile.totalRatings > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...List.generate(5, (i) => Icon(
                  i < profile.averageRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 20,
                  color: i < profile.averageRating.round() ? const Color(0xFFFBBF24) : Colors.white38,
                )),
                const SizedBox(width: 8),
                Text(
                  '${profile.averageRating.toStringAsFixed(1)} (${profile.totalRatings} ${profile.totalRatings == 1 ? 'rating' : 'ratings'})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70,
                  ),
                ),
              ],
            )
          else
            Text(
              'No ratings yet',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54),
            ),

          const SizedBox(height: 20),
          _buildVerifiedBadge(),
        ],
      ),
    );
  }

  Widget _buildAvatarStack(String name) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditBtn(UserProfile? profile) {
    return GestureDetector(
      onTap: () {
        if (profile != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditProfileScreen(profile: profile),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            "Verified NSUer",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentInfoCard(UserProfile? profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: _cardStyle(Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "STUDENT IDENTITY",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: kTextSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoRow(Icons.badge_rounded, "Student ID", profile?.studentId ?? 'Not set'),
          _divider(),
          _buildInfoRow(Icons.account_balance_rounded, "Department", profile?.department ?? 'Not set'),
          _divider(),
          _buildInfoRow(Icons.diversity_3_rounded, "Batch", profile?.batch ?? 'Not set'),
          _divider(),
          _buildInfoRow(Icons.smartphone_rounded, "Phone", profile?.phone ?? 'Not set'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final bool isSet = value != 'Not set' && value.isNotEmpty;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kPrimaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: kPrimaryBlue),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSet ? kTextPrimary : kTextSecondary.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
  );

  Widget _buildActionsSection(UserProfile? profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 12),
          child: Text(
            "MANAGEMENT",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: kTextSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        _buildMenuTile(
          Icons.history_rounded,
          "My Rides",
          "History of your journeys",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyRidesScreen()),
            );
          },
        ),
        _buildMenuTile(
          Icons.security_rounded,
          "Privacy Settings",
          "Manage your data visibility",
        ),
        _buildMenuTile(
          Icons.info_rounded,
          "Support Center",
          "Help and version information",
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Ryden',
              applicationVersion: '1.0.0',
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: _cardStyle(Colors.white),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kPrimaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: kPrimaryBlue, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: kTextSecondary,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
      ),
    );
  }

  Widget _buildSafetySection() {
    const color = Color(0xFFFF3131); // Strong Emergency Red
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: _cardStyle(color, borderColor: color),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showSafetyDialog(),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
            ),
            title: Text(
              "Safety & SOS",
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              "Emergency tools and contacts",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    const color = Color(0xFF334155); // Solid Slate Grey
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: _cardStyle(color, borderColor: color),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _showLogoutDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  "Log Out",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSafetyDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text("Safety & SOS", style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary)),
              const SizedBox(height: 4),
              Text("Your safety is our priority", style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextSecondary)),
              const SizedBox(height: 24),
              _safetyTile(Icons.phone_in_talk_rounded, "Emergency Call (999)", "Call national emergency services", Colors.red, () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("To call 999, use your phone dialer.", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                );
              }),
              const SizedBox(height: 8),
              _safetyTile(Icons.share_location_rounded, "Share Live Location", "Share your trip with trusted contacts", kPrimaryBlue, () {
                Navigator.pop(ctx);
              }),
              const SizedBox(height: 8),
              _safetyTile(Icons.shield_rounded, "Safety Tips", "Always verify driver identity before boarding", const Color(0xFF10B981), () {
                Navigator.pop(ctx);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _safetyTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: kTextPrimary)),
      subtitle: Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextSecondary)),
      trailing: Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Log Out?",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          "Are you sure you want to end your session?",
          style: GoogleFonts.plusJakartaSans(color: kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Stay",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: kTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Log Out"),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardStyle(Color color, {Color? borderColor}) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.02),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
    border: Border.all(color: borderColor ?? const Color(0xFFF1F5F9)),
  );
}
