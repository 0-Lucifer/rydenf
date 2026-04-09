import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/group_ride_model.dart';
import '../models/group_ride_request_model.dart';
import '../services/firestore_service.dart';
import '../widgets/profile_popup.dart';

class GroupRideRequestsScreen extends StatelessWidget {
  final GroupRide ride;
  const GroupRideRequestsScreen({super.key, required this.ride});

  static const Color kPrimaryBlue = Color(0xFF2E7CF6);
  static const Color kContentColor = Color(0xFF0F172A);
  static const Color kSecondaryText = Color(0xFF64748B);
  static const Color kBgColor = Color(0xFFF8FAFC);
  static const Color kBorderColor = Color(0xFFE2E8F0);
  static const Color kSuccessGreen = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kContentColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Join Requests",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: kContentColor)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.radio_button_checked_rounded, size: 12, color: kPrimaryBlue),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(ride.from, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: kSecondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, size: 14, color: kSecondaryText),
                ),
                const Icon(Icons.location_on_rounded, size: 12, color: Colors.redAccent),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(ride.to, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: kSecondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<GroupRideRequest>>(
        stream: FirestoreService.getGroupRideRequestsStream(ride.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
          }

          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("No requests yet",
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
                  const SizedBox(height: 4),
                  Text("People who want to join will appear here",
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade400)),
                ],
              ),
            );
          }

          // Separate by status
          final pending = requests.where((r) => r.status == 'pending').toList();
          final accepted = requests.where((r) => r.status == 'accepted').toList();
          final rejected = requests.where((r) => r.status == 'rejected').toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            children: [
              if (pending.isNotEmpty) ...[
                _sectionHeader("Pending", pending.length),
                ...pending.map((r) => _RequestCard(request: r, showActions: true)),
                const SizedBox(height: 24),
              ],
              if (accepted.isNotEmpty) ...[
                _sectionHeader("Accepted", accepted.length),
                ...accepted.map((r) => _RequestCard(request: r, showActions: false)),
                const SizedBox(height: 24),
              ],
              if (rejected.isNotEmpty) ...[
                _sectionHeader("Rejected", rejected.length),
                ...rejected.map((r) => _RequestCard(request: r, showActions: false)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: kContentColor)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: kPrimaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text("$count", style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimaryBlue)),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final GroupRideRequest request;
  final bool showActions;
  const _RequestCard({required this.request, required this.showActions});

  static const Color kPrimaryBlue = Color(0xFF2E7CF6);
  static const Color kContentColor = Color(0xFF0F172A);
  static const Color kSecondaryText = Color(0xFF64748B);
  static const Color kSuccessGreen = Color(0xFF10B981);
  static const Color kBorderColor = Color(0xFFE2E8F0);

  Color get _statusColor {
    switch (request.status) {
      case 'accepted': return kSuccessGreen;
      case 'rejected': return Colors.redAccent;
      default: return const Color(0xFFFFA726);
    }
  }

  String get _statusText {
    switch (request.status) {
      case 'accepted': return 'Accepted';
      case 'rejected': return 'Rejected';
      default: return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(request.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => showUserProfile(context, request.passengerId),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: kPrimaryBlue.withOpacity(0.1),
                  child: Text(
                    request.passengerName.isNotEmpty ? request.passengerName[0].toUpperCase() : '?',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: kPrimaryBlue, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => showUserProfile(context, request.passengerId),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              request.passengerName.isNotEmpty ? request.passengerName : 'Unknown',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: kContentColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.open_in_new_rounded, size: 12, color: kPrimaryBlue.withOpacity(0.5)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$timeAgo • ${request.seatsRequested} seat${request.seatsRequested > 1 ? 's' : ''} • Tap to view profile",
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kSecondaryText, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_statusText,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: _statusColor)),
              ),
            ],
          ),
          if (showActions && request.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleReject(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text("Decline", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAccept(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSuccessGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text("Accept", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleAccept(BuildContext context) async {
    final result = await FirestoreService.acceptGroupRideRequest(request.id!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          backgroundColor: result.success ? kSuccessGreen : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _handleReject(BuildContext context) async {
    final result = await FirestoreService.rejectGroupRideRequest(request.id!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          backgroundColor: result.success ? Colors.orange : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM dd').format(dt);
  }
}
