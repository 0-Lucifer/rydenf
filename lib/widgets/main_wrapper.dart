import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/trips_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/chat_list_screen.dart';
import '../services/firestore_service.dart';
import '../services/local_notification_service.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const RydenHome(),
    const TripsScreen(),
    const ChatListScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Cleanup expired data on app start
    FirestoreService.cleanupExpiredChats();
    FirestoreService.cleanupExpiredGroupRides();
    // Start listening for push notifications
    LocalNotificationService.instance.startListening();
  }

  Future<bool> _onWillPop() async {
    // If not on home tab, go back to home first
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return false;
    }
    // On home tab — show premium exit dialog
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.5),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        actionsPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFEE2E2),
                    const Color(0xFFFECACA).withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.exit_to_app_rounded,
                color: Color(0xFFEF4444),
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              'Leaving so soon?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'You\'re about to close Ryden.\nAre you sure?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            // Buttons in a row
            Row(
              children: [
                // Cancel button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Exit button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Yes, Exit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (shouldExit == true) exit(0);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: _buildPremiumNavbar(),
      ),
    );
  }

  Widget _buildPremiumNavbar() {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Sliding Indicator — updated for 5 items
            AnimatedAlign(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              alignment: Alignment(-1.0 + (_selectedIndex * (2.0 / 4.0)), -1.0),
              child: Container(
                width: MediaQuery.of(context).size.width / 5,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7CF6),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
              ),
            ),
            // Navigation Items — 5 tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.grid_view_rounded, "Explore"),
                _navItem(1, Icons.local_taxi_rounded, "Trips"),
                _navItemWithBadge(2, Icons.chat_bubble_rounded, "Chat", isChatBadge: true),
                _navItemWithBadge(3, Icons.notifications_rounded, "Alerts", isChatBadge: false),
                _navItem(4, Icons.person_rounded, "Account"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF2E7CF6) : const Color(0xFF9BA5B0),
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF2E7CF6) : const Color(0xFF9BA5B0),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItemWithBadge(int index, IconData icon, String label, {required bool isChatBadge}) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? const Color(0xFF2E7CF6) : const Color(0xFF9BA5B0),
                    size: 26,
                  ),
                  StreamBuilder<int>(
                    stream: isChatBadge
                        ? FirestoreService.getUnreadChatCount()
                        : FirestoreService.getUnreadNotificationCount(),
                    builder: (context, snap) {
                      final count = snap.data ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isChatBadge ? const Color(0xFF2E7CF6) : Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF2E7CF6) : const Color(0xFF9BA5B0),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
