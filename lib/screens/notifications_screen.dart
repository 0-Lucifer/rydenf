import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:async';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import 'ride_detail_screen.dart';
import 'ongoing_ride_screen.dart';
import 'group_ride_requests_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // --- Premium Design Tokens ---
  static const Color kPrimary = Color(0xFF2E7CF6); // Premium Blue
  static const Color kTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color kTextSecondary = Color(0xFF64748B); // Slate 500
  static const Color kSuccess = Color(0xFF10B981); // Emerald 500
  static const Color kDanger = Color(0xFFEF4444); // Rose 500
  static const Color kWarning = Color(0xFFF59E0B); // Amber 500
  static const Color kBackground = Color(0xFFF8FAFC); // Slate 50

  late Stream<List<AppNotification>> _notificationsStream;
  bool _timedOut = false;
  Timer? _timeoutTimer;
  // Track if we've received at least one emission from the stream
  bool _hasReceivedData = false;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    _timedOut = false;
    _hasReceivedData = false;
    _timeoutTimer?.cancel();
    _notificationsStream = FirestoreService.getNotificationsStream();
    // If no data comes within 4 seconds, show "No notifications"
    _timeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_hasReceivedData) {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF020617) : kBackground;

    return Scaffold(
      backgroundColor: bgColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive Padding Strategy
          final double horizontalPadding = constraints.maxWidth > 600
              ? (constraints.maxWidth - 600) / 2 + 20
              : 20;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildPremiumSliverAppBar(context, isDark, horizontalPadding),

              StreamBuilder<List<AppNotification>>(
                stream: _notificationsStream,
                builder: (context, snapshot) {
                  // Mark that we've received at least one emission
                  if (snapshot.hasData || snapshot.hasError) {
                    _hasReceivedData = true;
                    _timeoutTimer?.cancel();
                  }

                  // Show loading only while waiting AND we haven't timed out
                  if (!_hasReceivedData && !_timedOut) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 3)),
                    );
                  }

                  // Timed out with no data — show empty state
                  if (_timedOut && !_hasReceivedData) {
                    return SliverFillRemaining(child: _buildEmptyState(isDark));
                  }

                  // Stream had an error
                  if (snapshot.hasError) {
                    return SliverFillRemaining(child: _buildEmptyState(isDark));
                  }

                  final notifications = snapshot.data ?? [];
                  if (notifications.isEmpty) {
                    return SliverFillRemaining(child: _buildEmptyState(isDark));
                  }

                  return SliverPadding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          return RepaintBoundary(
                            child: _buildNotificationCard(context, notifications[index], isDark),
                          );
                        },
                        childCount: notifications.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPremiumSliverAppBar(BuildContext context, bool isDark, double horizontalPadding) {
    final canGoBack = Navigator.of(context).canPop();
    return SliverAppBar(
      expandedHeight: 140,
      collapsedHeight: 80,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: canGoBack
          ? Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.white,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: isDark ? Colors.white : kTextPrimary,
                    ),
                  ),
                ),
              ),
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(
          centerTitle: false,
          titlePadding: EdgeInsets.symmetric(
            horizontal: canGoBack ? horizontalPadding + 36 : horizontalPadding,
            vertical: 20,
          ),
          title: Text(
            "Notifications",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : kTextPrimary,
              letterSpacing: -1.2,
            ),
          ),
          background: Container(
            color: isDark ? const Color(0xFF020617).withOpacity(0.95) : kBackground,
          ),
        ),
      actions: [
        _buildMarkAllReadAction(isDark),
        SizedBox(width: horizontalPadding),
      ],
    );
  }

  Widget _buildGlassAction(IconData icon, VoidCallback onTap, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.white),
          ),
          child: IconButton(
              icon: Icon(icon, size: 16, color: isDark ? Colors.white : kTextPrimary),
              onPressed: onTap
          ),
        ),
      ),
    );
  }

  Widget _buildMarkAllReadAction(bool isDark) {
    return StreamBuilder<int>(
      stream: FirestoreService.getUnreadNotificationCount(),
      builder: (context, snap) {
        final unread = snap.data ?? 0;
        if (unread == 0) return const SizedBox.shrink();
        return Center(
          child: GestureDetector(
            onTap: () => FirestoreService.markAllNotificationsAsRead(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: kPrimary.withOpacity(0.1), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.done_all_rounded, size: 14, color: kPrimary),
                  const SizedBox(width: 8),
                  Text(
                    "Mark read",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 160, width: 160,
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_none_rounded, size: 70, color: kPrimary.withOpacity(0.15)),
                Positioned(
                  bottom: 40, right: 40,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_rounded, size: 20, color: kSuccess),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "No notifications",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : kTextPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "We'll notify you when someone\nupdates your journey.",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15, color: kTextSecondary, height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, AppNotification notification, bool isDark) {
    final iconData = _getIcon(notification.type);
    final iconColor = _getColor(notification.type);
    final timeAgo = _formatTimeAgo(notification.createdAt);

    return GestureDetector(
      onTap: () => _handleNotificationTap(context, notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: notification.isRead
                ? (isDark ? Colors.white.withOpacity(0.05) : Colors.white)
                : kPrimary.withOpacity(0.3),
            width: notification.isRead ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(isDark ? 0.4 : 0.06),
              blurRadius: 30,
              offset: const Offset(0, 15),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              if (!notification.isRead)
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(width: 6, color: kPrimary),
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIconBox(iconData, iconColor),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: notification.isRead ? FontWeight.w700 : FontWeight.w900,
                                    color: isDark ? Colors.white : kTextPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              Text(
                                timeAgo,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: kTextSecondary.withOpacity(0.7),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notification.body,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: kTextSecondary,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(child: Icon(icon, color: color, size: 26)),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'ride_accepted': return Icons.check_circle_outline_rounded;
      case 'ride_rejected': return Icons.cancel_outlined;
      case 'ride_request': return Icons.person_add_outlined;
      case 'ride_started': return Icons.directions_car_filled_rounded;
      case 'ride_completed': return Icons.flag_rounded;
      case 'ride_cancelled': return Icons.block_flipped;
      case 'group_ride_request': return Icons.group_add_rounded;
      case 'group_ride_accepted': return Icons.group_rounded;
      case 'group_ride_rejected': return Icons.group_off_rounded;
      case 'group_ride_started': return Icons.directions_car_filled_rounded;
      case 'group_ride_completed': return Icons.flag_rounded;
      default: return Icons.notifications_active_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'ride_accepted': return kSuccess;
      case 'ride_rejected': return kDanger;
      case 'ride_request': return kPrimary;
      case 'ride_started': return kWarning;
      case 'ride_completed': return kSuccess;
      case 'ride_cancelled': return kDanger;
      case 'group_ride_request': return kPrimary;
      case 'group_ride_accepted': return kSuccess;
      case 'group_ride_rejected': return kDanger;
      case 'group_ride_started': return kWarning;
      case 'group_ride_completed': return kSuccess;
      default: return kPrimary;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(dateTime);
  }

  // ─── Notification Tap Routing ──────────────────────────

  void _handleNotificationTap(BuildContext context, AppNotification notification) async {
    // Mark as read
    if (!notification.isRead && notification.id != null) {
      FirestoreService.markNotificationAsRead(notification.id!);
    }

    final type = notification.type;
    final rideId = notification.rideId;
    if (rideId == null) return;

    // Group ride notifications
    if (type.startsWith('group_ride_')) {
      if (type == 'group_ride_completed') {
        _showCompletedPopup(context, notification, isGroup: true);
        return;
      }

      // group_ride_request → navigate to join requests screen
      if (type == 'group_ride_request' && rideId != null) {
        try {
          final groupRide = await FirestoreService.getGroupRide(rideId);
          if (groupRide != null && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GroupRideRequestsScreen(ride: groupRide)),
            );
          }
        } catch (_) {}
        return;
      }

      // Other group ride notifications (accepted/rejected/started)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Check the Group Rides tab for details',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          backgroundColor: kPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // Regular ride notifications
    if (type == 'ride_completed') {
      _showCompletedPopup(context, notification, isGroup: false);
      return;
    }

    if (type == 'ride_started') {
      // Ongoing ride → navigate to ongoing screen
      Navigator.push(context, MaterialPageRoute(builder: (_) => OngoingRideScreen(rideId: rideId)));
      return;
    }

    if (type == 'ride_accepted' || type == 'ride_request') {
      // Check if ride is in_progress → go to ongoing screen, otherwise detail screen
      try {
        final ride = await FirestoreService.getRide(rideId);
        if (ride != null && context.mounted) {
          if (ride.status == 'in_progress') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => OngoingRideScreen(rideId: rideId)));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: rideId)));
          }
        }
      } catch (_) {
        if (context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: rideId)));
        }
      }
      return;
    }

    // Fallback — ride detail screen
    Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: rideId)));
  }

  void _showCompletedPopup(BuildContext context, AppNotification notification, {required bool isGroup}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: kSuccess.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 40, color: kSuccess),
            ),
            const SizedBox(height: 20),
            Text(
              isGroup ? 'Group Ride Completed' : 'Ride Completed',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20, fontWeight: FontWeight.w900, color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              notification.body,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, color: kTextSecondary, height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSuccess,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Got it!', style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white,
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
