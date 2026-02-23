import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildPremiumNavbar(),
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
