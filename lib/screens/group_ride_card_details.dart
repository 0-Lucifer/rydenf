import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_ride_model.dart';
import '../services/firestore_service.dart';
import '../widgets/profile_popup.dart';
import '../widgets/ride_map_preview.dart';
import 'group_ride_requests_screen.dart';
import 'chat_screen.dart';

// --- Redesigned UI Constants ---
class RydenTokens {
  static const Color primary = Color(0xFF2E7CF6);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const double cardRadius = 24.0;
  static const double sheetRadius = 32.0;
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 24);
}

/// Redesigned Entry Point — now accepts GroupRide model
void showGroupRideDetails(BuildContext context, GroupRide ride) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (context) => GroupRideDetailsSheet(ride: ride),
  );
}

class GroupRideDetailsSheet extends StatefulWidget {
  final GroupRide ride;
  const GroupRideDetailsSheet({super.key, required this.ride});

  @override
  State<GroupRideDetailsSheet> createState() => _GroupRideDetailsSheetState();
}

class _GroupRideDetailsSheetState extends State<GroupRideDetailsSheet> {
  bool _isRequesting = false;
  String _requestStatus = 'none'; // 'none', 'pending', 'accepted', 'rejected'
  bool _isLoadingStatus = true;
  StreamSubscription<String>? _requestStatusSub;

  double? _hostRating;
  int _hostTotalRatings = 0;

  bool get _isHost =>
      FirebaseAuth.instance.currentUser?.uid == widget.ride.hostId;

  @override
  void initState() {
    super.initState();
    _fetchHostRating();
    if (!_isHost) {
      _listenRequestStatus();
    } else {
      _isLoadingStatus = false;
    }
  }

  @override
  void dispose() {
    _requestStatusSub?.cancel();
    super.dispose();
  }

  void _fetchHostRating() async {
    final profile = await FirestoreService.getUserProfile(widget.ride.hostId);
    if (mounted && profile != null) {
      setState(() {
        _hostRating = profile.averageRating;
        _hostTotalRatings = profile.totalRatings;
      });
    }
  }

  void _listenRequestStatus() {
    if (widget.ride.id == null) { setState(() => _isLoadingStatus = false); return; }
    _requestStatusSub = FirestoreService
        .getUserRequestStatusStreamForRide(widget.ride.id!)
        .listen((status) {
      if (mounted) setState(() { _requestStatus = status; _isLoadingStatus = false; });
    });
  }

  void _handleJoinRequest() async {
    if (widget.ride.isFull || _isHost) return;
    if (widget.ride.id == null) return;

    setState(() => _isRequesting = true);

    final result = await FirestoreService.requestGroupRide(
      groupRideId: widget.ride.id!,
    );

    if (mounted) {
      setState(() {
        _isRequesting = false;
        if (result.success) _requestStatus = 'pending';
      });
      _showPremiumSnackBar(
        context,
        result.message,
        result.success ? RydenTokens.success : RydenTokens.danger,
      );
    }
  }

  void _handleEnterGC() async {
    if (widget.ride.id == null) return;
    setState(() => _isRequesting = true);
    final room = await FirestoreService.createOrGetGroupChat(widget.ride.id!);
    if (room != null && mounted) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room)));
    } else if (mounted) {
      setState(() => _isRequesting = false);
      _showPremiumSnackBar(context, "Could not open group chat.", RydenTokens.danger);
    }
  }

  void _handleChat() async {
    if (_isHost) {
      // Host → open group chat or requests
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupRideRequestsScreen(ride: widget.ride)),
      );
    } else {
      // Other user → create personal chat with host
      final room = await FirestoreService.createOrGetPersonalChat(widget.ride.hostId);
      if (room != null && mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
        );
      } else if (mounted) {
        Navigator.pop(context);
        _showPremiumSnackBar(
            context, "Could not start chat.", RydenTokens.danger);
      }
    }
  }

  void _handleManageRequests() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupRideRequestsScreen(ride: widget.ride)),
    );
  }

  void _handleStartRide() async {
    if (widget.ride.id == null) return;
    setState(() => _isRequesting = true);
    final result = await FirestoreService.startGroupRide(widget.ride.id!);
    if (mounted) {
      setState(() => _isRequesting = false);
      if (result.success) {
        Navigator.pop(context);
      }
      _showPremiumSnackBar(context, result.message, result.success ? RydenTokens.success : RydenTokens.danger);
    }
  }

  void _handleEndRide() async {
    if (widget.ride.id == null) return;
    showDialog(
      context: context,
      barrierColor: const Color(0xFF0F172A).withOpacity(0.5),
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        actionsPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFFEE2E2), const Color(0xFFFECACA).withOpacity(0.5)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stop_circle_rounded, color: Color(0xFFEF4444), size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'End Group Ride?',
              style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              'This will end the ride and dissolve the group.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Keep Going', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey[600])),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        setState(() => _isRequesting = true);
                        final result = await FirestoreService.completeGroupRide(widget.ride.id!);
                        if (mounted) {
                          Navigator.pop(context);
                          _showPremiumSnackBar(context, result.message, result.success ? RydenTokens.success : RydenTokens.danger);
                        }
                      },
                      style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text('End Ride', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showPremiumSnackBar(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  String _formatDepartureTime(DateTime dep) {
    final now = DateTime.now();
    if (dep.year == now.year && dep.month == now.month && dep.day == now.day) {
      return "Today, ${DateFormat('h:mm a').format(dep)}";
    } else if (dep.year == now.year && dep.month == now.month && dep.day == now.day + 1) {
      return "Tomorrow, ${DateFormat('h:mm a').format(dep)}";
    } else {
      return DateFormat('MMM dd, h:mm a').format(dep);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFull = widget.ride.isFull;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(RydenTokens.sheetRadius)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                )
              ],
            ),
            child: Column(
              children: [
                _buildDragHandle(isDark),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: RydenTokens.screenPadding,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildHeader(isFull, isDark),
                      const SizedBox(height: 24),
                      _buildStatsGrid(isDark),
                      const SizedBox(height: 32),
                      _buildRouteSection(isDark),
                      if (widget.ride.hasCoordinates) ...[
                        const SizedBox(height: 20),
                        RideMapPreview(
                          originLat: widget.ride.fromLat,
                          originLng: widget.ride.fromLng,
                          destLat: widget.ride.toLat,
                          destLng: widget.ride.toLng,
                          height: 180,
                          showRouteInfo: true,
                        ),
                      ],
                      const SizedBox(height: 32),
                      _buildHostSection(isDark),
                      const SizedBox(height: 32),
                      _buildRefinedSection("Ride Notes", _buildNotes(isDark), isDark),
                      const SizedBox(height: 24),
                      _buildRefinedSection("Rules & Safety", _buildGuidelines(isDark), isDark),
                      const SizedBox(height: 40),
                      _buildFooterActions(isDark),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                _buildStickyFooter(isFull, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: 48,
      height: 6,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildHeader(bool isFull, bool isDark) {
    final statusColor = isFull ? RydenTokens.danger : RydenTokens.success;
    final seatsLeft = widget.ride.seatsAvailable;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: statusColor.withOpacity(0.15)),
            boxShadow: [BoxShadow(color: statusColor.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: statusColor, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 6, spreadRadius: 2)],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _isHost
                    ? "YOUR RIDE"
                    : widget.ride.status == 'in_progress'
                        ? "RIDE IN PROGRESS"
                        : (isFull
                            ? "RIDE FULL"
                            : "$seatsLeft ${seatsLeft == 1 ? 'SEAT' : 'SEATS'} REMAINING"),
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    final timeText = _formatDepartureTime(widget.ride.departureTime);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(RydenTokens.cardRadius),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: _StatItem(Icons.schedule_rounded, "Time", timeText, isDark)),
            _buildVerticalDivider(isDark),
            Expanded(child: _StatItem(Icons.commute_rounded, "Mode", widget.ride.transport, isDark)),
            _buildVerticalDivider(isDark),
            Expanded(child: _StatItem(Icons.face_retouching_natural_rounded, "Gender", widget.ride.gender, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) => VerticalDivider(color: isDark ? Colors.white12 : Colors.grey[300], width: 1);

  Widget _buildRouteSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle("Route Details", isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RydenTokens.cardRadius),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RouteNode(Icons.radio_button_checked_rounded, RydenTokens.primary, "Pickup Point", widget.ride.from, isDark),
              Container(
                margin: const EdgeInsets.only(left: 11), height: 30, width: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [RydenTokens.primary, RydenTokens.danger.withOpacity(0.5)],
                  ),
                ),
              ),
              _RouteNode(Icons.location_on_rounded, RydenTokens.danger, "Drop-off Point", widget.ride.to, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHostSection(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle(_isHost ? "You (Host)" : "Host", isDark),
            TextButton(
              onPressed: () => showUserProfile(context, widget.ride.hostId),
              child: Text("View Profile", style: GoogleFonts.plusJakartaSans(color: RydenTokens.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RydenTokens.cardRadius),
            color: RydenTokens.primary.withOpacity(0.05),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: RydenTokens.primary,
                child: Text(
                  widget.ride.hostName.isNotEmpty ? widget.ride.hostName[0] : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ride.hostName.isNotEmpty ? widget.ride.hostName : 'Unknown',
                      style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: _hostTotalRatings > 0 ? Colors.amber : Colors.grey),
                        Text(
                          " ${_hostTotalRatings > 0 ? '${_hostRating!.toStringAsFixed(1)} ($_hostTotalRatings)' : 'No rating'} • ${_isHost ? 'You' : 'Trusted Host'}",
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.ride.isVerified)
                const Icon(Icons.verified_rounded, color: RydenTokens.primary, size: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRefinedSection(String title, Widget content, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title, isDark),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildNotes(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Text(
        widget.ride.notes.isNotEmpty ? widget.ride.notes : "Host has not added extra notes for this trip.",
        style: GoogleFonts.plusJakartaSans(height: 1.6, color: isDark ? Colors.white70 : Colors.black87),
      ),
    );
  }

  Widget _buildGuidelines(bool isDark) {
    final List<Map<String, dynamic>> rules = [
      {"icon": Icons.timer_outlined, "label": "Punctuality is required"},
      {"icon": Icons.groups_outlined, "label": "Respect co-passengers"},
      {"icon": Icons.smoke_free_rounded, "label": "No smoking inside"},
    ];
    return Column(
      children: rules.map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(r['icon'], size: 20, color: RydenTokens.primary),
            const SizedBox(width: 12),
            Text(r['label'], style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildFooterActions(bool isDark) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _showReportDialog(isDark),
        icon: const Icon(Icons.flag_outlined, size: 16),
        label: const Text("Report this ride"),
        style: TextButton.styleFrom(foregroundColor: Colors.grey, textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  void _showReportDialog(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text("Report this ride", style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 4),
              Text("Select a reason below", style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              for (final reason in ["Inappropriate behavior", "Safety concern", "Misleading ride details", "Spam or scam", "Other"])
                ListTile(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPremiumSnackBar(context, "Report submitted. Thank you!", const Color(0xFF10B981));
                  },
                  leading: const Icon(Icons.report_outlined, size: 20, color: Colors.redAccent),
                  title: Text(reason, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStickyFooter(bool isFull, bool isDark) {
    final status = widget.ride.status;
    final hasPassengers = widget.ride.passengers.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: _isHost
          ? _buildHostFooter(status, hasPassengers, isDark)
          : _isLoadingStatus
              ? const Center(child: SizedBox(height: 56, child: CircularProgressIndicator(color: RydenTokens.primary)))
              : _buildPassengerFooter(status, isFull, isDark),
    );
  }

  Widget _buildHostFooter(String status, bool hasPassengers, bool isDark) {
    if (status == 'in_progress') {
      // In progress: End Ride | Enter GC
      return Row(
        children: [
          Expanded(
            child: _CustomButton(
              onTap: _handleEndRide,
              icon: Icons.stop_circle_rounded,
              label: "End Ride",
              isPrimary: false,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CustomButton(
              onTap: _handleEnterGC,
              icon: Icons.forum_rounded,
              label: "Enter GC 💬",
              isPrimary: true,
              isLoading: _isRequesting,
              isDark: isDark,
            ),
          ),
        ],
      );
    }

    // Active/Full: Requests | Start Ride (if passengers) | Enter GC
    return Row(
      children: [
        Expanded(
          child: _CustomButton(
            onTap: _handleManageRequests,
            icon: Icons.people_alt_rounded,
            label: "Requests",
            isPrimary: false,
            isDark: isDark,
          ),
        ),
        if (hasPassengers) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _CustomButton(
              onTap: _handleStartRide,
              icon: Icons.play_arrow_rounded,
              label: "Start Ride",
              isPrimary: true,
              isLoading: _isRequesting,
              isDark: isDark,
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: _CustomButton(
            onTap: _handleEnterGC,
            icon: Icons.forum_rounded,
            label: "GC 💬",
            isPrimary: hasPassengers ? false : true,
            isLoading: _isRequesting,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerFooter(String status, bool isFull, bool isDark) {
    if (status == 'in_progress' && _requestStatus == 'accepted') {
      // Ongoing ride for accepted passenger
      return Row(
        children: [
          Expanded(
            child: _CustomButton(
              onTap: _handleChat,
              icon: Icons.chat_bubble_outline_rounded,
              label: "Chat Host",
              isPrimary: false,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CustomButton(
              onTap: _handleEnterGC,
              icon: Icons.forum_rounded,
              label: "Enter GC 💬",
              isPrimary: true,
              isLoading: _isRequesting,
              isDark: isDark,
            ),
          ),
        ],
      );
    }

    // Default passenger footer
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: _CustomButton(
            onTap: _handleChat,
            icon: Icons.chat_bubble_outline_rounded,
            label: "Chat with Host",
            isPrimary: false,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: _requestStatus == 'accepted'
              ? _CustomButton(
                  onTap: _handleEnterGC,
                  icon: Icons.forum_rounded,
                  label: "Enter GC 💬",
                  isPrimary: true,
                  isLoading: _isRequesting,
                  isDark: isDark,
                )
              : _requestStatus == 'pending'
                  ? _CustomButton(
                      onTap: null,
                      icon: Icons.hourglass_top_rounded,
                      label: "Requested ⏳",
                      isPrimary: false,
                      isDark: isDark,
                    )
                  : _CustomButton(
                      onTap: isFull ? null : _handleJoinRequest,
                      label: isFull ? "Ride Full" : "Request to Join",
                      isPrimary: true,
                      isLoading: _isRequesting,
                      isDark: isDark,
                    ),
        ),
      ],
    );
  }
}

// --- Internal Reusable Components ---

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionTitle(this.title, this.isDark);
  @override
  Widget build(BuildContext context) => Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black, letterSpacing: 0.3));
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool isDark;

  const _StatItem(this.icon, this.label, this.value, this.isDark);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: RydenTokens.primary, size: 22),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.bold)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
        ),
      ],
    );
  }
}

class _RouteNode extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, val;
  final bool isDark;
  const _RouteNode(this.icon, this.color, this.title, this.val, this.isDark);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.bold)),
              Text(val, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final IconData? icon;
  final bool isPrimary, isLoading, isDark;
  const _CustomButton({this.onTap, required this.label, this.icon, required this.isPrimary, this.isLoading = false, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary ? RydenTokens.primary : (isDark ? Colors.white12 : const Color(0xFFF1F5F9));
    final fgColor = isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black);

    return Material(
      color: onTap == null ? Colors.grey[300] : bgColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, color: fgColor, size: 20), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: fgColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
