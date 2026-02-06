import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color kPrimaryBlue = Color(0xFF2E7CF6);
    const Color kBackgroundColor = Color(0xFFF8FAFC);
    const Color kTextPrimary = Color(0xFF0F172A);
    const Color kTextSecondary = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          "Profile",
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 30),
            _buildProfileHeader(kPrimaryBlue, kTextPrimary, kTextSecondary),
            const SizedBox(height: 30),
            _buildStudentInfoCard(kPrimaryBlue, kTextPrimary, kTextSecondary),
            const SizedBox(height: 30),
            _buildSettingsSection(kPrimaryBlue, kTextPrimary, kTextSecondary),
            const SizedBox(height: 30),
            _buildSafetySection(kTextPrimary, kTextSecondary),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Color primaryColor, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const CircleAvatar(
                radius: 65,
                backgroundColor: Color(0xFFE2E8F0),
                backgroundImage: AssetImage('assets/images/anonto-profile.jpg'),
              ),
            ),
            Positioned(
              bottom: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF10B981),
                  size: 28,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          "Anonto Bormon",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Verified Student",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentInfoCard(Color primaryColor, Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "STUDENT DETAILS",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoRow(Icons.badge_outlined, "Student ID", "2212302642", primaryColor, textPrimary, textSecondary),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          _buildInfoRow(Icons.school_outlined, "Department", "Computer Science", primaryColor, textPrimary, textSecondary),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          _buildInfoRow(Icons.groups_outlined, "Batch", "Spring 2022", primaryColor, textPrimary, textSecondary),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color primaryColor, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: primaryColor),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsSection(Color primaryColor, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 12),
          child: Text(
            "SETTINGS",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        _buildMenuTile(Icons.edit_outlined, "Edit Profile", primaryColor, textPrimary),
        _buildMenuTile(Icons.account_balance_wallet_outlined, "Payment Methods", primaryColor, textPrimary),
        _buildMenuTile(Icons.settings_suggest_outlined, "Preferences", primaryColor, textPrimary),
      ],
    );
  }

  Widget _buildSafetySection(Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
        ),
        title: Text(
          "Safety & Emergency",
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: const Color(0xFFB91C1C),
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          "SOS tools and emergency contacts",
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFEF4444).withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFFB91C1C)),
        onTap: () {},
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, Color primaryColor, Color textPrimary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: textPrimary,
            fontSize: 15,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFFCBD5E1)),
        onTap: () {},
      ),
    );
  }
}
