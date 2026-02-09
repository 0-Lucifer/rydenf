import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';
import '../services/firestore_service.dart';
import 'ride_detail_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> with SingleTickerProviderStateMixin {
  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kTextPrimary = Color(0xFF0F172A);
  static const Color kTextSecondary = Color(0xFF64748B);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyOffers(),
                _buildMyBookings(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Text(
                    "My Trips",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                labelColor: kPrimary,
                unselectedLabelColor: kTextSecondary,
                labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: "My Offers"),
                  Tab(text: "My Bookings"),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  MY OFFERS TAB
  // ───────────────────────────────────────────────────────

  Widget _buildMyOffers() {
    return StreamBuilder<List<Ride>>(
      stream: FirestoreService.getUserRidesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kPrimary));
        }

        final rides = snapshot.data ?? [];
        if (rides.isEmpty) {
          return _emptyState(
            Icons.directions_car_outlined,
            "No rides offered yet",
            "Rides you offer will appear here",
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: rides.length,
          itemBuilder: (context, index) => _buildOfferCard(rides[index]),
        );
      },
    );
  }

  Widget _buildOfferCard(Ride ride) {
    final formattedDate = DateFormat('EEE, MMM dd').format(ride.departureTime);
    final formattedTime = DateFormat('hh:mm a').format(ride.departureTime);
    final isActive = ride.status == 'active';
    final isFull = ride.status == 'full';

    Color statusColor;
    String statusLabel;
    if (isActive) {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'Active';
    } else if (isFull) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Full';
    } else if (ride.status == 'cancelled') {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'Cancelled';
    } else {
      statusColor = kPrimary;
      statusLabel = ride.status;
    }

    return GestureDetector(
      onTap: () {
        if (ride.id != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => RideDetailScreen(rideId: ride.id!),
          ));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      ride.vehicleType == VehicleType.bike ? Icons.two_wheeler_rounded : Icons.directions_car_filled_rounded,
                      color: kPrimary, size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${ride.origin} → ${ride.destination}",
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: kTextPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text("$formattedDate • $formattedTime",
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusLabel, style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.w800, color: statusColor,
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _statChip(Icons.event_seat_outlined, "${ride.seatsAvailable}/${ride.seatsTotal}"),
                  const SizedBox(width: 10),
                  _statChip(Icons.attach_money_rounded, "৳${ride.pricePerSeat.toInt()}"),
                  const SizedBox(width: 10),
                  _statChip(Icons.people_outline, "${ride.passengers.length} booked"),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  MY BOOKINGS TAB
  // ───────────────────────────────────────────────────────

  Widget _buildMyBookings() {
    return StreamBuilder<List<RideRequest>>(
      stream: FirestoreService.getMyBookingsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kPrimary));
        }

        final bookings = snapshot.data ?? [];
        if (bookings.isEmpty) {
          return _emptyState(
            Icons.bookmark_border_rounded,
            "No bookings yet",
            "Rides you book will appear here",
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: bookings.length,
          itemBuilder: (context, index) => _BookingCard(booking: bookings[index]),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────
  //  SHARED WIDGETS
  // ───────────────────────────────────────────────────────

  Widget _emptyState(IconData icon, String title, String subtitle) {
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
            child: Icon(icon, size: 50, color: kPrimary.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text(title, style: GoogleFonts.plusJakartaSans(
            fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary,
          )),
          const SizedBox(height: 8),
          Text(subtitle, style: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: kTextSecondary,
          )),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kTextSecondary),
          const SizedBox(width: 5),
          Text(text, style: GoogleFonts.plusJakartaSans(
            fontSize: 12, fontWeight: FontWeight.w700, color: kTextSecondary,
          )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  BOOKING CARD (separate widget that fetches ride data)
// ═══════════════════════════════════════════════════════

class _BookingCard extends StatefulWidget {
  final RideRequest booking;
  const _BookingCard({required this.booking});

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kTextPrimary = Color(0xFF0F172A);
  static const Color kTextSecondary = Color(0xFF64748B);
  static const Color kGreen = Color(0xFF10B981);
  static const Color kRed = Color(0xFFEF4444);

  Ride? _ride;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  Future<void> _loadRide() async {
    final ride = await FirestoreService.getRide(widget.booking.rideId);
    if (mounted) {
      setState(() {
        _ride = ride;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
      );
    }

    if (_ride == null) return const SizedBox.shrink();

    final formattedDate = DateFormat('EEE, MMM dd').format(_ride!.departureTime);
    final formattedTime = DateFormat('hh:mm a').format(_ride!.departureTime);

    Color statusColor;
    String statusLabel;
    switch (widget.booking.status) {
      case 'accepted':
        statusColor = kGreen;
        statusLabel = 'Confirmed';
        break;
      case 'rejected':
        statusColor = kRed;
        statusLabel = 'Rejected';
        break;
      case 'cancelled':
        statusColor = kTextSecondary;
        statusLabel = 'Cancelled';
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'Pending';
    }

    final canCancel = widget.booking.status == 'pending' || widget.booking.status == 'accepted';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => RideDetailScreen(rideId: widget.booking.rideId),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kPrimary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _ride!.vehicleType == VehicleType.bike ? Icons.two_wheeler_rounded : Icons.directions_car_filled_rounded,
                          color: kPrimary, size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${_ride!.origin} → ${_ride!.destination}",
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: kTextPrimary),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text("$formattedDate • $formattedTime",
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(statusLabel, style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, fontWeight: FontWeight.w800, color: statusColor,
                        )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: kPrimary.withOpacity(0.08),
                        child: Text(
                          _ride!.driverName.isNotEmpty ? _ride!.driverName[0].toUpperCase() : '?',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12, color: kPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _ride!.driverName.isNotEmpty ? _ride!.driverName : 'Driver',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary),
                      ),
                      const Spacer(),
                      Text("৳${_ride!.pricePerSeat.toInt()}",
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (canCancel)
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                    onTap: () => _showCancelDialog(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cancel_outlined, size: 16, color: kRed),
                          const SizedBox(width: 6),
                          Text("Cancel Booking", style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w700, color: kRed,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Cancel Booking?", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(
          "Your seat will be released back for others.",
          style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Keep", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: kTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await FirestoreService.cancelBooking(widget.booking.id!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result.message, style: const TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: result.success ? kGreen : kRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text("Cancel", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
