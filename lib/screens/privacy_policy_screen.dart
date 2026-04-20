import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shown once on first launch. The user must accept before proceeding.
class PrivacyPolicyScreen extends StatefulWidget {
  final VoidCallback onAccepted;

  const PrivacyPolicyScreen({super.key, required this.onAccepted});

  static const String _acceptedKey = 'privacy_policy_accepted';

  /// Check if the user has already accepted the privacy policy.
  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_acceptedKey) ?? false;
  }

  /// Mark the privacy policy as accepted.
  static Future<void> markAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_acceptedKey, true);
  }

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool _scrolledToBottom = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 50) {
      if (!_scrolledToBottom) setState(() => _scrolledToBottom = true);
    }
  }

  Future<void> _accept() async {
    await PrivacyPolicyScreen.markAccepted();
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Privacy & Terms",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Please review and accept to continue",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Policy content
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E293B).withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      _sectionTitle("1. Introduction"),
                      _sectionBody(
                        "Welcome to Ryden, a university ride-sharing platform designed to connect students for safe, affordable, and convenient travel. "
                        "By using this app, you agree to the following terms and conditions."
                      ),

                      _sectionTitle("2. Information We Collect"),
                      _bulletPoint("Name, email address, and university affiliation"),
                      _bulletPoint("Location data (pickup and drop-off points)"),
                      _bulletPoint("Ride history, preferences, and booking details"),
                      _bulletPoint("Device information for push notifications"),
                      _bulletPoint("Chat messages between riders and hosts"),

                      _sectionTitle("3. How We Use Your Information"),
                      _bulletPoint("To match you with available rides and riders"),
                      _bulletPoint("To facilitate communication between ride hosts and passengers"),
                      _bulletPoint("To calculate fair pricing based on distance"),
                      _bulletPoint("To send notifications about ride updates, requests, and confirmations"),
                      _bulletPoint("To improve app performance and user experience"),

                      _sectionTitle("4. Data Sharing"),
                      _sectionBody(
                        "We do not sell or rent your personal information to third parties. "
                        "Your data is only shared with other users as necessary to facilitate rides "
                        "(e.g., your name is visible to ride hosts and passengers). "
                        "We use Firebase services by Google for authentication, data storage, and notifications."
                      ),

                      _sectionTitle("5. Location Data"),
                      _sectionBody(
                        "Ryden uses your location to provide ride-sharing services, including finding nearby rides, "
                        "calculating distances, and tracking active rides. Location access is requested only when needed "
                        "and can be revoked through your device settings at any time."
                      ),

                      _sectionTitle("6. Data Security"),
                      _sectionBody(
                        "We implement industry-standard security measures to protect your data. "
                        "All communications are encrypted, and access to personal data is restricted. "
                        "However, no method of electronic storage is 100% secure."
                      ),

                      _sectionTitle("7. User Responsibilities"),
                      _bulletPoint("Provide accurate information when creating your profile"),
                      _bulletPoint("Treat fellow riders and hosts with respect"),
                      _bulletPoint("Do not use the platform for any illegal or harmful activities"),
                      _bulletPoint("Report any suspicious or inappropriate behavior"),

                      _sectionTitle("8. Ride Safety"),
                      _sectionBody(
                        "Ryden is a platform that connects riders. We do not employ drivers or guarantee the safety of rides. "
                        "Users participate at their own risk and are encouraged to verify ride details before traveling. "
                        "Always share your ride details with a trusted person."
                      ),

                      _sectionTitle("9. Account Deletion"),
                      _sectionBody(
                        "You may request the deletion of your account and associated data at any time "
                        "through the app settings. Upon deletion, your personal data will be permanently removed "
                        "from our systems within 30 days."
                      ),

                      _sectionTitle("10. Changes to This Policy"),
                      _sectionBody(
                        "We may update this Privacy Policy from time to time. Continued use of the app "
                        "after changes constitutes acceptance of the updated terms. "
                        "We will notify users of significant changes through in-app notifications."
                      ),

                      _sectionTitle("11. Contact Us"),
                      _sectionBody(
                        "If you have any questions or concerns about this Privacy Policy, "
                        "please contact us through the app's Settings page or reach out to the Ryden team."
                      ),

                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Last updated: April 2026",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Accept button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  if (!_scrolledToBottom)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        "Scroll down to read the full policy",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: AnimatedOpacity(
                      opacity: _scrolledToBottom ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 300),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _scrolledToBottom
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : [],
                        ),
                        child: TextButton(
                          onPressed: _scrolledToBottom ? _accept : null,
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: Text(
                            "I Agree & Continue",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _sectionBody(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: const Color(0xFF475569),
          height: 1.7,
        ),
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF4F46E5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF475569),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
