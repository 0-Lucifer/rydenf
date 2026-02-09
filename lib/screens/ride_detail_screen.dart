import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class RideDetailScreen extends StatefulWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kTextPrimary = Color(0xFF0F172A);
  static const Color kTextSecondary = Color(0xFF64748B);
  static const Color kGreen = Color(0xFF10B981);
  static const Color kRed = Color(0xFFEF4444);

  bool _isRequesting = false;

  String? get _currentUid => AuthService.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<Ride?>(
        stream: FirestoreService.getRideStream(widget.rideId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimary));
          }
          final ride = snapshot.data;
          if (ride == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 50, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text("Ride not found", style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade500,
                  )),
                ],
              ),
            );
          }

          final isDriver = ride.driverId == _currentUid;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(child: _buildHeader(ride)),
              // Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),
                    _buildRouteCard(ride),
                    const SizedBox(height: 16),
                    _buildRideInfoGrid(ride),
                    const SizedBox(height: 16),
                    _buildDriverCard(ride),
                    if (isDriver) ...[
                      const SizedBox(height: 16),
                      _buildRequestsSection(ride),
                    ],
                    if (ride.stops.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildStopsCard(ride),
                    ],
                    const SizedBox(height: 30),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<Ride?>(
        stream: FirestoreService.getRideStream(widget.rideId),
        builder: (context, snapshot) {
          final ride = snapshot.data;
          if (ride == null) return const SizedBox.shrink();

          final isDriver = ride.driverId == _currentUid;
          final isPassenger = ride.passengers.contains(_currentUid);

          return _buildBottomBar(ride, isDriver, isPassenger);
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  HEADER
  // ───────────────────────────────────────────────────────

  Widget _buildHeader(Ride ride) {
    final formattedDate = DateFormat('EEEE, MMM dd').format(ride.departureTime);
    final formattedTime = DateFormat('hh:mm a').format(ride.departureTime);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E7CF6), Color(0xFF4AC7FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  _buildStatusBadge(ride.status),
                ],
              ),
              const SizedBox(height: 20),
              // Vehicle type
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      ride.vehicleType == VehicleType.bike
                          ? Icons.two_wheeler_rounded
                          : Icons.directions_car_filled_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.vehicleType == VehicleType.bike ? "Bike Ride" : "Car Ride",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "$formattedDate • $formattedTime",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Stats row
              Row(
                children: [
                  _headerStat(Icons.event_seat_rounded, "${ride.seatsAvailable}/${ride.seatsTotal} seats"),
                  const SizedBox(width: 16),
                  _headerStat(Icons.attach_money_rounded, "৳${ride.pricePerSeat.toInt()}/seat"),
                  const SizedBox(width: 16),
                  if (ride.instantMatch)
                    _headerStat(Icons.bolt_rounded, "Instant"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = kGreen;
        label = 'Active';
        break;
      case 'full':
        color = const Color(0xFFF59E0B);
        label = 'Full';
        break;
      case 'cancelled':
        color = kRed;
        label = 'Cancelled';
        break;
      case 'completed':
        color = kPrimary;
        label = 'Completed';
        break;
      default:
        color = kTextSecondary;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w800, color: color,
        ),
      ),
    );
  }

  Widget _headerStat(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.plusJakartaSans(
            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
          )),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  ROUTE CARD
  // ───────────────────────────────────────────────────────

  Widget _buildRouteCard(Ride ride) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: _cardDeco(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const SizedBox(height: 4),
              _dot(kPrimary),
              _line(40),
              _dot(kRed),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PICKUP", style: _labelStyle()),
                const SizedBox(height: 4),
                Text(ride.origin, style: _valueStyle()),
                const SizedBox(height: 26),
                Text("DROP-OFF", style: _labelStyle()),
                const SizedBox(height: 4),
                Text(ride.destination, style: _valueStyle()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  INFO GRID
  // ───────────────────────────────────────────────────────

  Widget _buildRideInfoGrid(Ride ride) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _infoTile(Icons.people_outline_rounded, "Gender Pref", ride.genderPreference)),
          const SizedBox(width: 12),
          Expanded(child: _infoTile(
            Icons.bolt_rounded,
            "Booking",
            ride.instantMatch ? "Instant" : "Approval",
          )),
          const SizedBox(width: 12),
          Expanded(child: _infoTile(
            Icons.directions_car_outlined,
            "Vehicle",
            ride.vehicleModel,
          )),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Icon(icon, size: 22, color: kPrimary),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.plusJakartaSans(
            fontSize: 10, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 0.5,
          )),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w800, color: kTextPrimary,
          ), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  DRIVER CARD
  // ───────────────────────────────────────────────────────

  Widget _buildDriverCard(Ride ride) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kPrimary.withOpacity(0.2), width: 2),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: kPrimary.withOpacity(0.08),
              child: Text(
                ride.driverName.isNotEmpty ? ride.driverName[0].toUpperCase() : '?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20, fontWeight: FontWeight.w800, color: kPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.driverName.isNotEmpty ? ride.driverName : 'Unknown Driver',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      ride.rating ?? "5.0",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text("Verified", style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, fontWeight: FontWeight.w700, color: kGreen,
                      )),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_rounded, color: kPrimary, size: 20),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  STOPS CARD
  // ───────────────────────────────────────────────────────

  Widget _buildStopsCard(Ride ride) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("STOPOVERS", style: _labelStyle()),
          const SizedBox(height: 12),
          ...ride.stops.map((stop) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                _dot(const Color(0xFFF59E0B)),
                const SizedBox(width: 14),
                Text(stop, style: _valueStyle()),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  REQUESTS SECTION (DRIVER VIEW)
  // ───────────────────────────────────────────────────────

  Widget _buildRequestsSection(Ride ride) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inbox_rounded, size: 20, color: kPrimary),
              const SizedBox(width: 10),
              Text("Ride Requests", style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary,
              )),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<RideRequest>>(
            stream: FirestoreService.getRequestsForRide(widget.rideId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2),
                ));
              }
              final requests = snapshot.data ?? [];
              if (requests.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text("No requests yet",
                      style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 14),
                    ),
                  ),
                );
              }
              return Column(
                children: requests.map((req) => _buildRequestTile(req, ride)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTile(RideRequest req, Ride ride) {
    final isPending = req.status == 'pending';

    Color statusColor;
    String statusLabel;
    switch (req.status) {
      case 'accepted':
        statusColor = kGreen;
        statusLabel = 'Accepted';
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: kPrimary.withOpacity(0.1),
                child: Text(
                  req.passengerName.isNotEmpty ? req.passengerName[0].toUpperCase() : '?',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800, color: kPrimary, fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.passengerName.isNotEmpty ? req.passengerName : 'Passenger',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 14, color: kTextPrimary,
                      ),
                    ),
                    Text(
                      "${req.seatsRequested} seat${req.seatsRequested > 1 ? 's' : ''} requested",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel, style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w700, color: statusColor,
                )),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleReject(req.id!),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text("Reject", style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, color: kRed, fontSize: 13,
                    )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAccept(req.id!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text("Accept", style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13,
                    )),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  BOTTOM BAR
  // ───────────────────────────────────────────────────────

  Widget _buildBottomBar(Ride ride, bool isDriver, bool isPassenger) {
    final isCancelled = ride.status == 'cancelled';
    final isFull = ride.status == 'full';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          // Price display
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Per Seat", style: GoogleFonts.plusJakartaSans(
                fontSize: 11, fontWeight: FontWeight.w600, color: kTextSecondary,
              )),
              Text("৳${ride.pricePerSeat.toInt()}", style: GoogleFonts.plusJakartaSans(
                fontSize: 24, fontWeight: FontWeight.w900, color: kTextPrimary,
              )),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Builder(builder: (_) {
              if (isCancelled) {
                return _actionButton("Ride Cancelled", null, kTextSecondary);
              }

              if (isDriver) {
                return _actionButton("Cancel Ride", () => _showCancelRideDialog(ride), kRed);
              }

              if (isPassenger) {
                return _actionButton("Cancel Booking", () => _showCancelBookingDialog(ride), kRed);
              }

              if (isFull) {
                return _actionButton("Ride Full", null, kTextSecondary);
              }

              // Passenger can request
              return _actionButton(
                _isRequesting ? "Requesting..." : (ride.instantMatch ? "Book Instantly" : "Request Seat"),
                _isRequesting ? null : () => _handleRequest(ride),
                kPrimary,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String text, VoidCallback? onTap, Color color) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isRequesting && text == "Requesting..."
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(text, style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white,
              )),
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  ACTIONS
  // ───────────────────────────────────────────────────────

  Future<void> _handleRequest(Ride ride) async {
    if (ride.driverId == _currentUid) {
      _showSnack("You can't book your own ride.", false);
      return;
    }

    setState(() => _isRequesting = true);
    final result = await FirestoreService.requestRide(
      rideId: ride.id!,
      instantBooking: ride.instantMatch,
    );
    setState(() => _isRequesting = false);
    if (mounted) _showSnack(result.message, result.success);
  }

  Future<void> _handleAccept(String requestId) async {
    final result = await FirestoreService.acceptRequest(requestId);
    if (mounted) _showSnack(result.message, result.success);
  }

  Future<void> _handleReject(String requestId) async {
    final result = await FirestoreService.rejectRequest(requestId);
    if (mounted) _showSnack(result.message, result.success);
  }

  void _showCancelRideDialog(Ride ride) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Cancel Ride?", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(
          "This will cancel the ride and all existing bookings. This action cannot be undone.",
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
              final result = await FirestoreService.cancelRide(ride.id!);
              if (mounted) _showSnack(result.message, result.success);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text("Cancel Ride", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCancelBookingDialog(Ride ride) {
    // Find the user's accepted request to cancel
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Cancel Booking?", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(
          "Your seat will be released and someone else may take it.",
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
              // Find the user's accepted/pending request
              final requests = await FirestoreService.getRequestsForRide(ride.id!).first;
              final myRequest = requests.where(
                (r) => r.passengerId == _currentUid && (r.status == 'accepted' || r.status == 'pending'),
              ).firstOrNull;
              if (myRequest != null) {
                final result = await FirestoreService.cancelBooking(myRequest.id!);
                if (mounted) _showSnack(result.message, result.success);
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

  void _showSnack(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: success ? kGreen : kRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ───────────────────────────────────────────────────────
  //  HELPERS
  // ───────────────────────────────────────────────────────

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
  );

  TextStyle _labelStyle() => GoogleFonts.plusJakartaSans(
    fontSize: 10, fontWeight: FontWeight.w800, color: kTextSecondary, letterSpacing: 1.2,
  );

  TextStyle _valueStyle() => GoogleFonts.plusJakartaSans(
    fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary,
  );

  Widget _dot(Color color) => Container(
    width: 12, height: 12,
    decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
    child: Center(child: Container(
      width: 6, height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    )),
  );

  Widget _line(double h) => Container(
    width: 2, height: h,
    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(1)),
  );
}
