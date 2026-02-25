import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_gate.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color kPrimary = Color(0xFF4F46E5);
  static const Color kBg = Color(0xFFF8FAFC);
  static const Color kSurface = Colors.white;
  static const Color kTextPrimary = Color(0xFF0F172A);
  static const Color kTextSecondary = Color(0xFF64748B);
  static const Color kBorder = Color(0xFFE2E8F0);
  static const Color kDanger = Color(0xFFEF4444);

  // Toggle states
  bool _notificationsEnabled = true;
  bool _chatNotifications = true;
  bool _rideAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // ── Notifications ──
          _sectionLabel('NOTIFICATIONS'),
          _settingsCard([
            _toggleTile(
              icon: Icons.notifications_rounded,
              iconColor: kPrimary,
              title: 'Push Notifications',
              subtitle: 'Enable or disable all notifications',
              value: _notificationsEnabled,
              onChanged: (v) => setState(() {
                _notificationsEnabled = v;
                if (!v) {
                  _chatNotifications = false;
                  _rideAlerts = false;
                }
              }),
            ),
            _divider(),
            _toggleTile(
              icon: Icons.chat_bubble_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Chat Notifications',
              subtitle: 'New message alerts',
              value: _chatNotifications,
              onChanged: _notificationsEnabled
                  ? (v) => setState(() => _chatNotifications = v)
                  : null,
            ),
            _divider(),
            _toggleTile(
              icon: Icons.directions_car_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Ride Alerts',
              subtitle: 'Booking updates and requests',
              value: _rideAlerts,
              onChanged: _notificationsEnabled
                  ? (v) => setState(() => _rideAlerts = v)
                  : null,
            ),
          ]),

          const SizedBox(height: 20),

          // ── Account ──
          _sectionLabel('ACCOUNT'),
          _settingsCard([
            _navTile(
              icon: Icons.person_rounded,
              iconColor: kPrimary,
              title: 'Edit Profile',
              subtitle: 'Name, university, avatar',
              onTap: () async {
                final profile = await FirestoreService.getUserProfile(
                  AuthService.currentUser?.uid ?? '',
                );
                if (profile != null && mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => EditProfileScreen(profile: profile),
                  ));
                }
              },
            ),
            _divider(),
            _navTile(
              icon: Icons.lock_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Change Password',
              subtitle: 'Update your password via email',
              onTap: () => _showChangePasswordDialog(),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Storage & Data ──
          _sectionLabel('STORAGE & DATA'),
          _settingsCard([
            _navTile(
              icon: Icons.cached_rounded,
              iconColor: const Color(0xFF06B6D4),
              title: 'Clear Cache',
              subtitle: 'Free up local storage',
              onTap: () => _showClearCacheDialog(),
            ),
          ]),

          const SizedBox(height: 20),

          // ── About ──
          _sectionLabel('ABOUT'),
          _settingsCard([
            _infoTile(
              icon: Icons.info_rounded,
              iconColor: kPrimary,
              title: 'App Version',
              trailing: '1.0.0',
            ),
          ]),

          const SizedBox(height: 28),

          _logoutButton(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  BUILDING BLOCKS
  // ═══════════════════════════════════════════════════════

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: kTextSecondary,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _settingsCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: kSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kBorder.withValues(alpha: 0.5)),
    ),
    child: Column(children: children),
  );

  Widget _divider() => Divider(
    height: 1,
    thickness: 1,
    color: kBorder.withValues(alpha: 0.5),
    indent: 60,
  );

  Widget _toggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final disabled = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: disabled ? 0.05 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: disabled ? kTextSecondary.withValues(alpha: 0.4) : iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: disabled ? kTextSecondary : kTextPrimary,
                )),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w500, color: kTextSecondary,
                )),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: iconColor,
          ),
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary,
                    )),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w500, color: kTextSecondary,
                    )),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: kTextSecondary.withValues(alpha: 0.5), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary,
            )),
          ),
          Text(trailing, style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary,
          )),
        ],
      ),
    );
  }

  Widget _logoutButton() => SizedBox(
    width: double.infinity,
    height: 52,
    child: TextButton(
      onPressed: () => _showLogoutDialog(),
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFFEF2F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.logout_rounded, color: kDanger, size: 20),
          const SizedBox(width: 10),
          Text('Log Out', style: GoogleFonts.plusJakartaSans(
            fontSize: 16, fontWeight: FontWeight.w700, color: kDanger,
          )),
        ],
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════
  //  DIALOGS
  // ═══════════════════════════════════════════════════════

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: kSurface,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        actionsPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: kDanger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: kDanger, size: 26),
            ),
            const SizedBox(height: 16),
            Text('Log Out?', style: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary,
            )),
            const SizedBox(height: 8),
            Text('You can always log back in later.', style: GoogleFonts.plusJakartaSans(
              fontSize: 14, fontWeight: FontWeight.w500, color: kTextSecondary,
            )),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700, color: kTextSecondary,
                      )),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
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
                      style: TextButton.styleFrom(
                        backgroundColor: kDanger,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Log Out', style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                      )),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: kSurface,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        actionsPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, color: Color(0xFF8B5CF6), size: 26),
            ),
            const SizedBox(height: 16),
            Text('Reset Password', style: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary,
            )),
            const SizedBox(height: 8),
            Text(
              'We\'ll send a password reset link to your email.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w500, color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700, color: kTextSecondary,
                      )),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await AuthService.sendPasswordReset(
                            AuthService.currentUser?.email ?? '',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Reset link sent! Check your email.',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to send reset email.',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: kDanger,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Send Link', style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                      )),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: kSurface,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        actionsPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cached_rounded, color: Color(0xFF06B6D4), size: 26),
            ),
            const SizedBox(height: 16),
            Text('Clear Cache?', style: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary,
            )),
            const SizedBox(height: 8),
            Text(
              'This will clear locally cached data.\nYou won\'t lose any account data.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w500, color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700, color: kTextSecondary,
                      )),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        FirestoreService.clearProfileCache();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Cache cleared!',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Clear', style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                      )),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
