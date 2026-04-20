import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import 'ongoing_ride_screen.dart';

class TrackRideScreen extends StatelessWidget {
  const TrackRideScreen({super.key});

  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kTextPrimary = Color(0xFF0F172A);
  static const Color kTextSecondary = Color(0xFF64748B);
  static const Color kBackground = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, String>?>(
      stream: FirestoreService.getActiveRideInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: kBackground,
            body: const Center(
              child: CircularProgressIndicator(color: kPrimary, strokeWidth: 3),
            ),
          );
        }

        final info = snapshot.data;

        // Active ride found — show the OngoingRideScreen directly
        if (info != null) {
          final rideId = info['rideId'] ?? '';
          final type = info['type'] ?? 'ride';
          final isGroup = type == 'group_ride';

          if (!isGroup && rideId.isNotEmpty) {
            return OngoingRideScreen(rideId: rideId);
          }

          // Group ride — show a simple info card since group rides use a different model
          return Scaffold(
            backgroundColor: kBackground,
            body: _buildGroupRideState(info),
          );
        }

        // No active ride — show the empty state
        return Scaffold(
          backgroundColor: kBackground,
          body: _buildNoRideState(),
        );
      },
    );
  }

  Widget _buildNoRideState() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: kPrimary.withOpacity(0.1),
                          width: 2,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.location_off_rounded,
                      size: 56,
                      color: kPrimary.withOpacity(0.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "No ride going on\nright now",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: kTextPrimary,
                  letterSpacing: -0.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "When you start or join a ride,\nyou'll be able to track it here.",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: kTextSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupRideState(Map<String, String> info) {
    final from = info['from'] ?? '';
    final to = info['to'] ?? '';
    final role = info['role'] ?? '';

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Color(0xFF10B981),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Group Ride Active",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  role,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: kPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "$from → $to",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kPrimary.withOpacity(0.1)),
                ),
                child: Center(
                  child: Text(
                    "Check Group Rides tab for details",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
