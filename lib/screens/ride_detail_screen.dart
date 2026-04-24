import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/profile_popup.dart';
import '../widgets/ride_map_preview.dart';
import 'chat_screen.dart';
import 'ongoing_ride_screen.dart';

class RideDetailScreen extends StatefulWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  // Premium "Royal Blue & Azure" Style System
  static const Color kPrimary = Color(0xFF1E3A8A); // Deep Navy
  static const Color kAccent = Color(0xFF3B82F6);  // Azure Blue
  static const Color kBackground = Color(0xFFF8FAFC);
  static const Color kSurface = Colors.white;
  static const Color kTextMain = Color(0xFF0F172A);
  static const Color kTextSub = Color(0xFF64748B);
  static const Color kSuccess = Color(0xFF10B981);
  static const Color kError = Color(0xFFEF4444);
  static const Color kBorder = Color(0xFFE2E8F0);

  bool _isRequesting = false;
  String _requestStatus = 'none'; // 'none', 'pending', 'accepted', 'rejected'
  bool _isLoadingStatus = true;

  // 5-second cancel window after requesting
  bool _cancelWindowActive = false;
  Timer? _cancelTimer;
  String? get _currentUid => AuthService.currentUser?.uid;

  double? _driverRating;
  int _driverTotalRatings = 0;

  @override
  void initState() {
    super.initState();
    _loadRequestStatus();
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  void _fetchDriverRating(String driverId) async {
    final profile = await FirestoreService.getUserProfile(driverId);
    if (mounted && profile != null) {
      setState(() {
        _driverRating = profile.averageRating;
        _driverTotalRatings = profile.totalRatings;
      });
    }
  }

  void _loadRequestStatus() async {
    final status = await FirestoreService.getUserRequestStatusForRegularRide(widget.rideId);
    if (mounted) setState(() { _requestStatus = status; _isLoadingStatus = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.9),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextMain, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: StreamBuilder<Ride?>(
        stream: FirestoreService.getRideStream(widget.rideId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2));
          }
          final ride = snapshot.data;
          if (ride == null) return const Center(child: Text("Ride details not found"));

          final isDriver = ride.driverId == _currentUid;
          final isPassenger = ride.passengers.contains(_currentUid);

          return Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(ride),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLocationCard(ride),
                          if (ride.hasCoordinates) ...[
                            const SizedBox(height: 20),
                            RideMapPreview(
                              originLat: ride.originLat,
                              originLng: ride.originLng,
                              destLat: ride.destinationLat,
                              destLng: ride.destinationLng,
                              height: 200,
                              showRouteInfo: true,
                            ),
                          ],
                          const SizedBox(height: 32),
                          _buildGridSpecs(ride),
                          const SizedBox(height: 32),
                          _buildHostSection(ride),
                          if (isDriver) ...[
                            const SizedBox(height: 32),
                            _buildDriverRequests(ride),
                          ],
                          if (ride.stops.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildStopoverList(ride),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildBottomActionPanel(ride, isDriver, isPassenger),
            ],
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  PREMIUM BLUE HEADER
  // ───────────────────────────────────────────────────────

  Widget _buildHeader(Ride ride) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 110, 24, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimary, Color(0xFF1E40AF)], // Sophisticated Blue Gradient
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(48),
          bottomRight: Radius.circular(48),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _headerTag(ride.vehicleType == VehicleType.bike ? "BIKE" : "CAR"),
              const SizedBox(width: 12),
              _headerTag(ride.status.toUpperCase(), isStatus: true, status: ride.status),
            ],
          ),
          const SizedBox(height: 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  ride.origin,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.route_rounded, color: Colors.white.withOpacity(0.6), size: 28),
                const SizedBox(width: 12),
                Text(
                  ride.destination,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                DateFormat('EEE, MMM dd • hh:mm a').format(ride.departureTime),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerTag(String label, {bool isStatus = false, String status = ''}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isStatus ? Colors.white.withOpacity(0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isStatus ? Colors.white.withOpacity(0.3) : Colors.white10),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  LOCATION CARD
  // ───────────────────────────────────────────────────────

  Widget _buildLocationCard(Ride ride) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: kTextMain.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Column(
              children: [
                const Icon(Icons.trip_origin_rounded, color: kAccent, size: 20),
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: kBorder,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                const Icon(Icons.location_on_rounded, color: kPrimary, size: 20),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Departure Point", style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextSub, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(ride.origin, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: kTextMain), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Destination", style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextSub, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(ride.destination, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: kTextMain), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  SPECS GRID
  // ───────────────────────────────────────────────────────

  Widget _buildGridSpecs(Ride ride) {
    return Row(
      children: [
        _specItem(Icons.airline_seat_recline_extra_rounded, ride.seatsAvailable.toString(), "Seats"),
        _specDivider(),
        _specItem(Icons.wc_rounded, ride.genderPreference, "Gender"),
        _specDivider(),
        _specItem(ride.instantMatch ? Icons.bolt_rounded : Icons.approval_rounded, ride.instantMatch ? "Instant" : "Review", "Match"),
      ],
    );
  }

  Widget _specDivider() => Container(width: 1, height: 30, color: kTextSub.withOpacity(0.1));

  Widget _specItem(IconData icon, String val, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: kAccent.withOpacity(0.8)),
          const SizedBox(height: 8),
          Text(val, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: kTextMain)),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: kTextSub)),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  HOST SECTION
  // ───────────────────────────────────────────────────────

  Widget _buildHostSection(Ride ride) {
    final isDriver = ride.driverId == _currentUid;
    final hasRating = _driverTotalRatings > 0;

    // Trigger fetch if not yet loaded
    if (_driverRating == null && _driverTotalRatings == 0) {
      _fetchDriverRating(ride.driverId);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: kTextMain.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => showUserProfile(context, ride.driverId),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: kPrimary.withOpacity(0.05),
                  child: Text(ride.driverName[0].toUpperCase(), style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => showUserProfile(context, ride.driverId),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(ride.driverName, style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: kTextMain)),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.open_in_new_rounded, size: 12, color: kAccent.withOpacity(0.5)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, size: 14, color: hasRating ? Colors.amber : Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              hasRating ? "${_driverRating!.toStringAsFixed(1)} ($_driverTotalRatings)" : "No rating",
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text("Verified Host", style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: kSuccess)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!isDriver)
                GestureDetector(
                  onTap: () => _handleChatWithDriver(ride),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.chat_bubble_rounded, color: kAccent, size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => showUserProfile(context, ride.driverId),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_rounded, size: 16, color: kAccent),
                  const SizedBox(width: 6),
                  Text("View Profile", style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: kAccent)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleChatWithDriver(Ride ride) async {
    final room = await FirestoreService.createOrGetPersonalChat(ride.driverId);
    if (room != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room)));
    } else if (mounted) {
      _showSnack("Could not start chat.", false);
    }
  }

  // ───────────────────────────────────────────────────────
  //  DRIVER REQUESTS
  // ───────────────────────────────────────────────────────

  Widget _buildDriverRequests(Ride ride) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Rider Requests", style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: kTextMain)),
        const SizedBox(height: 16),
        StreamBuilder<List<RideRequest>>(
          stream: FirestoreService.getRequestsForRide(widget.rideId),
          builder: (context, snapshot) {
            final requests = (snapshot.data ?? [])
                .where((r) => r.status == 'pending' || r.status == 'accepted')
                .toList();
            if (requests.isEmpty) return _emptyRequests();
            return Column(children: requests.map((req) => _requestRow(req)).toList());
          },
        ),
      ],
    );
  }

  Widget _emptyRequests() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(20)),
    child: Center(child: Text("No requests yet", style: GoogleFonts.plusJakartaSans(color: kTextSub, fontSize: 13))),
  );

  Widget _requestRow(RideRequest req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: kTextSub.withOpacity(0.05))),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => showUserProfile(context, req.passengerId),
            child: CircleAvatar(radius: 16, backgroundColor: kAccent.withOpacity(0.1), child: Text(req.passengerName[0], style: const TextStyle(fontSize: 12, color: kAccent))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => showUserProfile(context, req.passengerId),
              child: Row(
                children: [
                  Flexible(child: Text(req.passengerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new_rounded, size: 10, color: kAccent.withOpacity(0.4)),
                ],
              ),
            ),
          ),
          if (req.status == 'pending') ...[
            _actionBtn(Icons.close, kError, () => _handleReject(req.id!)),
            const SizedBox(width: 8),
            _actionBtn(Icons.check, kSuccess, () => _handleAccept(req.id!)),
          ] else
            Text(req.status.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSub)),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 16, color: color)),
    );
  }

  // ───────────────────────────────────────────────────────
  //  STOPOVERS
  // ───────────────────────────────────────────────────────

  Widget _buildStopoverList(Ride ride) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Planned Stops", style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: kTextMain)),
        const SizedBox(height: 12),
        ...ride.stops.map((stop) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: kAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(stop, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: kTextMain), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        )),
      ],
    );
  }

  // ───────────────────────────────────────────────────────
  //  ACTION PANEL
  // ───────────────────────────────────────────────────────

  Widget _buildBottomActionPanel(Ride ride, bool isDriver, bool isPassenger) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: kTextMain.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, -8))],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("TOTAL COST", style: GoogleFonts.plusJakartaSans(fontSize: 10, color: kTextSub, fontWeight: FontWeight.w800, letterSpacing: 1)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("৳${ride.pricePerSeat.toInt()}", style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w900, color: kTextMain)),
                    if (ride.maxFare != null && ride.pricePerSeat < ride.maxFare!) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          "৳${ride.maxFare!.toInt()}",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kTextSub,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: kTextSub,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (ride.maxFare != null && ride.pricePerSeat < ride.maxFare!)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kSuccess.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Below Max",
                      style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: kSuccess),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 32),
            Expanded(child: _buildPrimaryBtn(ride, isDriver, isPassenger)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryBtn(Ride ride, bool isDriver, bool isPassenger) {
    if (ride.status == 'cancelled') return _disabledTag("CANCELLED", kError);
    if (ride.status == 'completed') return _disabledTag("COMPLETED", kTextSub);

    if (isDriver) {
      if (ride.status == 'in_progress') return _actionBtnLarge("ONGOING TRIP", () => Navigator.push(context, MaterialPageRoute(builder: (_) => OngoingRideScreen(rideId: ride.id!))), kAccent);
      if (ride.passengers.isNotEmpty) return _actionBtnLarge("START TRIP", () => _handleStartRide(ride), kSuccess);
      return _actionBtnLarge("CANCEL TRIP", () => _showCancelRideDialog(ride), kError);
    }

    if (isPassenger) {
      if (ride.status == 'in_progress') return _actionBtnLarge("TRACK TRIP", () => Navigator.push(context, MaterialPageRoute(builder: (_) => OngoingRideScreen(rideId: ride.id!))), kAccent);
      return _actionBtnLarge("CANCEL BOOKING", () => _showCancelBookingDialog(ride), kError);
    }

    if (ride.status == 'full') return _disabledTag("FULL", kTextSub);

    // Show status-aware button
    if (_isLoadingStatus) {
      return const SizedBox(height: 56, child: Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2)));
    }
    if (_requestStatus == 'pending') {
      if (_cancelWindowActive) {
        return _actionBtnLarge("CANCEL REQUEST", () => _showCancelRequestDialog(ride), kError);
      }
      return _disabledTag("REQUESTED ⏳", const Color(0xFFF59E0B));
    }
    if (_requestStatus == 'accepted') return _disabledTag("ACCEPTED ✓", kSuccess);

    return _actionBtnLarge(_isRequesting ? "SENDING..." : (ride.instantMatch ? "BOOK NOW" : "REQUEST SEAT"), _isRequesting ? null : () => _handleRequest(ride), kAccent);
  }

  Widget _actionBtnLarge(String label, VoidCallback? onTap, Color color) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
    );
  }

  Widget _disabledTag(String label, Color color) {
    return Container(
      height: 56,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(color: color, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
        ),
      ),
    );
  }

  // LOGIC
  Color _getStatusColor(String s) => s == 'active' ? kSuccess : (s == 'full' ? Color(0xFFF59E0B) : kError);

  Future<void> _handleRequest(Ride ride) async {
    setState(() => _isRequesting = true);
    final result = await FirestoreService.requestRide(rideId: ride.id!);
    if (!mounted) return;
    setState(() {
      _isRequesting = false;
      if (result.success) {
        _requestStatus = ride.instantMatch ? 'accepted' : 'pending';
        // Start 5-second cancel window for non-instant rides
        if (!ride.instantMatch) {
          _cancelWindowActive = true;
          _cancelTimer?.cancel();
          _cancelTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => _cancelWindowActive = false);
          });
        }
      }
    });
    _showSnack(result.message, result.success);
  }

  Future<void> _handleAccept(String requestId) async {
    final result = await FirestoreService.acceptRequest(requestId);
    if (mounted) _showSnack(result.message, result.success);
  }

  Future<void> _handleReject(String requestId) async {
    final result = await FirestoreService.rejectRequest(requestId);
    if (mounted) _showSnack(result.message, result.success);
  }

  Future<void> _handleStartRide(Ride ride) async {
    final res = await FirestoreService.startRide(ride.id!);
    if (res.success && mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OngoingRideScreen(rideId: ride.id!)));
  }

  void _showCancelRideDialog(Ride ride) {
    showDialog(
      context: context,
      barrierColor: kTextMain.withOpacity(0.5),
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: kSurface,
        contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        actionsPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFEE2E2),
                    const Color(0xFFFECACA).withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              'Cancel this trip?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kTextMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All pending requests will be rejected\nand passengers will be notified.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kTextSub,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Keep Trip',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kTextSub,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                            color: const Color(0xFFEF4444).withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          FirestoreService.cancelRide(ride.id!);
                        },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Cancel Trip',
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
  }

  void _showCancelBookingDialog(Ride ride) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Cancel your booking?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No")), ElevatedButton(onPressed: () async { Navigator.pop(ctx); final requests = await FirestoreService.getRequestsForRide(ride.id!).first; final myReq = requests.where((r) => r.passengerId == _currentUid && (r.status == 'accepted' || r.status == 'pending')).firstOrNull; if (myReq != null) FirestoreService.cancelBooking(myReq.id!); }, child: const Text("Cancel"))]));
  }

  void _showCancelRequestDialog(Ride ride) {
    showDialog(
      context: context,
      barrierColor: kTextMain.withOpacity(0.5),
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: kSurface,
        contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        actionsPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFEE2E2),
                    const Color(0xFFFECACA).withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.undo_rounded, color: Color(0xFFEF4444), size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              'Withdraw Request?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kTextMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your seat request will be cancelled\nand the driver won\'t see it.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kTextSub,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Keep It',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kTextSub,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                            color: const Color(0xFFEF4444).withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleCancelRequest(ride);
                        },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Withdraw',
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
  }

  Future<void> _handleCancelRequest(Ride ride) async {
    _cancelTimer?.cancel();
    setState(() => _cancelWindowActive = false);
    final result = await FirestoreService.cancelPendingRideRequest(ride.id!);
    if (mounted) {
      if (result.success) {
        setState(() => _requestStatus = 'none');
      }
      _showSnack(result.message, result.success);
    }
  }

  void _showSnack(String m, bool s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: s ? kSuccess : kError, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20)));
}
