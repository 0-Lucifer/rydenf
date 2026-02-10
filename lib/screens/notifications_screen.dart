import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import 'ride_detail_screen.dart';
import 'ongoing_ride_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kTextPrimary = Color(0xFF0F172A);
  static const Color kTextSecondary = Color(0xFF64748B);
  static const Color kGreen = Color(0xFF10B981);
  static const Color kRed = Color(0xFFEF4444);
  static const Color kAmber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: FirestoreService.getNotificationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kPrimary));
                }

                final notifications = snapshot.data ?? [];
                if (notifications.isEmpty) {
                  return _buildEmpty();
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) => _buildNotificationCard(context, notifications[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, 4))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Row(
            children: [
              Text("Notifications",
                style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: kTextPrimary),
              ),
              const Spacer(),
              StreamBuilder<int>(
                stream: FirestoreService.getUnreadNotificationCount(),
                builder: (context, snap) {
                  final unread = snap.data ?? 0;
                  if (unread == 0) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: () => FirestoreService.markAllNotificationsAsRead(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text("Mark all read", style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary,
                      )),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded, size: 50, color: kPrimary.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text("Nothing yet", style: GoogleFonts.plusJakartaSans(
            fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary,
          )),
          const SizedBox(height: 8),
          Text("You'll be notified about ride\nupdates here", style: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: kTextSecondary, height: 1.5,
          ), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, AppNotification notification) {
    final iconData = _getIcon(notification.type);
    final iconColor = _getColor(notification.type);
    final timeAgo = _formatTimeAgo(notification.createdAt);

    return GestureDetector(
      onTap: () {
        // Mark as read
        if (!notification.isRead && notification.id != null) {
          FirestoreService.markNotificationAsRead(notification.id!);
        }
        // Navigate to ride
        if (notification.rideId != null) {
          if (notification.type == 'ride_started' || notification.type == 'ride_completed') {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => OngoingRideScreen(rideId: notification.rideId!),
            ));
          } else {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => RideDetailScreen(rideId: notification.rideId!),
            ));
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : kPrimary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: notification.isRead
              ? null
              : Border.all(color: kPrimary.withOpacity(0.1), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(notification.title, style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                          color: kTextPrimary,
                        )),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notification.body, style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: kTextSecondary, fontWeight: FontWeight.w500, height: 1.4,
                  )),
                  const SizedBox(height: 6),
                  Text(timeAgo, style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'ride_accepted':
        return Icons.check_circle_rounded;
      case 'ride_rejected':
        return Icons.cancel_rounded;
      case 'ride_request':
        return Icons.person_add_rounded;
      case 'ride_started':
        return Icons.directions_car_rounded;
      case 'ride_completed':
        return Icons.flag_rounded;
      case 'ride_cancelled':
        return Icons.block_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'ride_accepted':
        return kGreen;
      case 'ride_rejected':
        return kRed;
      case 'ride_request':
        return kPrimary;
      case 'ride_started':
        return kAmber;
      case 'ride_completed':
        return kGreen;
      case 'ride_cancelled':
        return kRed;
      default:
        return kPrimary;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(dateTime);
  }
}
