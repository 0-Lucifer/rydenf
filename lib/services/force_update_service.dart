import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class ForceUpdateService {
  ForceUpdateService._();

  // Store URLs are centralized in AppConfig

  /// Call once from MainWrapper.initState to gate the app.
  static Future<void> checkAndPrompt(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .get();

      if (!doc.exists) return; // no config yet — allow through

      final minVersion = doc.data()?['min_app_version'] as String?;
      if (minVersion == null || minVersion.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      if (_isOlderThan(currentVersion, minVersion)) {
        if (context.mounted) {
          _showForceUpdateDialog(context, minVersion);
        }
      }
    } catch (_) {
      // Silently fail — don't lock users out if Firestore is unreachable
    }
  }

  /// Semantic-version compare: returns true if [current] < [minimum].
  static bool _isOlderThan(String current, String minimum) {
    final cur = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final min = minimum.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad to equal length
    while (cur.length < 3) cur.add(0);
    while (min.length < 3) min.add(0);

    for (int i = 0; i < 3; i++) {
      if (cur[i] < min[i]) return true;
      if (cur[i] > min[i]) return false;
    }
    return false; // equal — not older
  }

  // ── Non-dismissible premium dialog ─────────────────────
  static void _showForceUpdateDialog(BuildContext context, String minVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.85),
      builder: (ctx) => PopScope(
        canPop: false, // block system back button
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon ──
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2E7CF6).withValues(alpha: 0.15),
                        const Color(0xFF2E7CF6).withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Color(0xFF2E7CF6),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Title ──
                Text(
                  'Update Required',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Body ──
                Text(
                  'A new version of Ryden is available.\n'
                  'Please update to continue using the app.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Minimum version: v$minVersion',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Update Button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7CF6), Color(0xFF1D6AE5)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF2E7CF6).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: () => _openStore(),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.download_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Update Now',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openStore() async {
    final url = Platform.isIOS ? AppConfig.appStoreUrl : AppConfig.playStoreUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
