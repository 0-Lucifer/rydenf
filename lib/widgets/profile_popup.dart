import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

/// Shows a premium bottom-sheet profile card for any user.
/// Usage: `showUserProfile(context, userId)` or `showUserProfileDirect(context, profile)`
Future<void> showUserProfile(BuildContext context, String userId) async {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ProfileSheetLoader(userId: userId),
  );
}

Future<void> showUserProfileDirect(BuildContext context, UserProfile profile) async {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ProfileSheetContent(profile: profile),
  );
}

class _ProfileSheetLoader extends StatelessWidget {
  final String userId;
  const _ProfileSheetLoader({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: FirestoreService.getUserProfile(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 300,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7CF6)),
            ),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return Container(
            height: 200,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Center(
              child: Text("Profile not found",
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.grey)),
            ),
          );
        }

        return _ProfileSheetContent(profile: profile);
      },
    );
  }
}

class _ProfileSheetContent extends StatelessWidget {
  final UserProfile profile;
  const _ProfileSheetContent({required this.profile});

  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kDark = Color(0xFF0F172A);
  static const Color kMuted = Color(0xFF64748B);
  static const Color kBg = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final memberSince = DateFormat('MMM yyyy').format(profile.createdAt);
    final initials = profile.displayName.isNotEmpty
        ? profile.displayName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Avatar + Name
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kPrimary, Color(0xFF1D6AE5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: kPrimary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile.displayName.isNotEmpty ? profile.displayName : 'Anonymous',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: kDark,
            ),
          ),
          const SizedBox(height: 4),

          // Rating display
          if (profile.totalRatings > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(5, (i) => Icon(
                    i < profile.averageRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: i < profile.averageRating.round() ? const Color(0xFFF59E0B) : Colors.grey[300],
                  )),
                  const SizedBox(width: 6),
                  Text(
                    '${profile.averageRating.toStringAsFixed(1)} (${profile.totalRatings})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w700, color: kMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'No ratings yet',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600),
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_rounded, size: 14, color: kPrimary),
              const SizedBox(width: 4),
              Text(
                "Verified Member",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kPrimary,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.circle, size: 3, color: kMuted),
              ),
              Text(
                "Since $memberSince",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Info Grid
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0).withOpacity(0.5)),
            ),
            child: Column(
              children: [
                if (profile.department.isNotEmpty)
                  _infoRow(Icons.school_rounded, "Department", profile.department),
                if (profile.batch.isNotEmpty)
                  _infoRow(Icons.calendar_today_rounded, "Batch", profile.batch),
                if (profile.studentId.isNotEmpty)
                  _infoRow(Icons.badge_rounded, "Student ID", profile.studentId),
                if (profile.gender.isNotEmpty)
                  _infoRow(
                    profile.gender.toLowerCase() == 'male'
                        ? Icons.male_rounded
                        : profile.gender.toLowerCase() == 'female'
                            ? Icons.female_rounded
                            : Icons.wc_rounded,
                    "Gender",
                    profile.gender,
                  ),
                if (profile.email.isNotEmpty)
                  _infoRow(Icons.email_rounded, "Email", profile.email),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Safety badge
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_rounded, size: 18, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Identity Verified",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10B981),
                          )),
                      Text(
                        "This user's information has been verified",
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Close button
          Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBg,
                  foregroundColor: kDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text("Close",
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(icon, size: 16, color: kPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: kMuted,
                      letterSpacing: 0.5,
                    )),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kDark,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
