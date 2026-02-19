import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';
import '../services/firestore_service.dart';
import 'ride_detail_screen.dart';
import 'ongoing_ride_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> with SingleTickerProviderStateMixin {
  // --- Premium Design System Tokens ---
  static const Color kAccent = Color(0xFF2E7CF6); // Premium Blue
  static const Color kPrimary = Color(0xFF0F172A); // Slate 900
  static const Color kSecondary = Color(0xFF64748B); // Slate 500
  static const Color kSuccess = Color(0xFF10B981); // Emerald 500
  static const Color kDanger = Color(0xFFF43F5E); // Rose 500
  static const Color kBackground = Color(0xFFF8FAFC); // Slate 50

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF020617) : kBackground;

    return Scaffold(
      backgroundColor: bgColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = constraints.maxWidth > 1024
              ? (constraints.maxWidth - 1000) / 2
              : constraints.maxWidth > 600 ? 40 : 16;

          return Stack(
            children: [
              if (!isDark) ...[
                _buildAmbientBlob(kAccent.withOpacity(0.05), 300, -80, -80),
                _buildAmbientBlob(kSuccess.withOpacity(0.03), 250, 200, null, right: -60),
              ],

              SafeArea(
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    _buildPremiumHeader(isDark, horizontalPadding),
                    _buildStickyTabBar(isDark, horizontalPadding),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOffersList(isDark, horizontalPadding),
                      _buildBookingsList(isDark, horizontalPadding),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAmbientBlob(Color color, double size, double? top, double? left, {double? right, double? bottom}) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 100, spreadRadius: 50)],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(bool isDark, double horizontalPadding) {
    return SliverAppBar(
      expandedHeight: 120,
      collapsedHeight: 70,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding + 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "My Trips",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32, fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : kPrimary,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Keep track of your shared journeys",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: kSecondary, fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyTabBar(bool isDark, double horizontalPadding) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        minHeight: 68, maxHeight: 68,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: isDark ? const Color(0xFF020617).withOpacity(0.8) : kBackground.withOpacity(0.8),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? kAccent : Colors.white,
                    boxShadow: isDark ? [] : [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: isDark ? Colors.white : kAccent,
                  unselectedLabelColor: kSecondary,
                  labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                  unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [Tab(text: "My Offers"), Tab(text: "My Bookings")],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOffersList(bool isDark, double horizontalPadding) {
    return StreamBuilder<List<Ride>>(
      stream: FirestoreService.getUserRidesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 3));
        }
        final rides = snapshot.data ?? [];
        if (rides.isEmpty) return _buildEmptyState(Icons.directions_car_rounded, "No Offers Yet", "Rides you publish will appear here.", isDark);

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 100),
          physics: const BouncingScrollPhysics(),
          itemCount: rides.length,
          itemBuilder: (context, index) => _StaggeredAnimation(
            index: index,
            child: _PremiumTripCard(ride: rides[index], isDark: isDark),
          ),
        );
      },
    );
  }

  Widget _buildBookingsList(bool isDark, double horizontalPadding) {
    return StreamBuilder<List<RideRequest>>(
      stream: FirestoreService.getMyBookingsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 3));
        }
        final bookings = snapshot.data ?? [];
        if (bookings.isEmpty) return _buildEmptyState(Icons.bookmark_outline_rounded, "No Bookings", "The trips you join will be listed here.", isDark);

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 100),
          physics: const BouncingScrollPhysics(),
          itemCount: bookings.length,
          itemBuilder: (context, index) => _StaggeredAnimation(
            index: index,
            child: _PremiumBookingCard(request: bookings[index], isDark: isDark),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: kAccent.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(icon, size: 64, color: kAccent.withOpacity(0.2)),
          ),
          const SizedBox(height: 24),
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : kPrimary)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kSecondary, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// --- Enhanced Animation ---
class _StaggeredAnimation extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggeredAnimation({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + (index * 80)),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: child,
    );
  }
}

// --- Redesigned Premium Trip Card (Offers) ---
class _PremiumTripCard extends StatelessWidget {
  final Ride ride;
  final bool isDark;
  const _PremiumTripCard({required this.ride, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM dd').format(ride.departureTime);
    final timeStr = DateFormat('hh:mm a').format(ride.departureTime);
    final status = _getStatus(ride.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Stack(
        children: [
          // Floating Status Badge
          Positioned(
            top: 16,
            right: 16,
            child: _StatusBadge(label: status.label, color: status.color),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                if (ride.id == null) return;
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ride.status == 'in_progress' ? OngoingRideScreen(rideId: ride.id!) : RideDetailScreen(rideId: ride.id!),
                ));
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 8), // Room for badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _VehicleIcon(type: ride.vehicleType),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildJourneyTimeline(isDark),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const SizedBox(height: 24), // Offset for badge above
                            Text(
                              "৳${ride.pricePerSeat.toInt()}",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24, fontWeight: FontWeight.w900,
                                color: _TripsScreenState.kAccent, letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              "per seat",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10, fontWeight: FontWeight.w700, color: _TripsScreenState.kSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatChip(Icons.calendar_today_rounded, dateStr, isDark),
                          _StatChip(Icons.access_time_rounded, timeStr, isDark),
                          _StatChip(Icons.people_alt_rounded, "${ride.seatsAvailable}/${ride.seatsTotal}", isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyTimeline(bool isDark) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: 24,
              child: Column(
                children: [
                  Icon(Icons.trip_origin_rounded, size: 14, color: _TripsScreenState.kAccent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: CustomPaint(
                        painter: _VerticalRouteCurvePainter(),
                        child: const SizedBox(width: 24),
                      ),
                    ),
                  ),
                  Icon(Icons.location_on_rounded, size: 14, color: _TripsScreenState.kDanger),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ride.origin,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : _TripsScreenState.kPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Text(
                  ride.destination,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : _TripsScreenState.kPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _StatusData _getStatus(String s) {
    switch (s) {
      case 'active': return _StatusData("Active", const Color(0xFF10B981));
      case 'full': return _StatusData("Full", const Color(0xFFF59E0B));
      case 'in_progress': return _StatusData("On Route", const Color(0xFF2E7CF6));
      case 'cancelled': return _StatusData("Cancelled", const Color(0xFFF43F5E));
      default: return _StatusData("Completed", Colors.grey);
    }
  }
}

// --- Vertical Route Curve Painter ---
class _VerticalRouteCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF3B82F6), // Blue
        const Color(0xFF06B6D4), // Cyan
        const Color(0xFF10B981), // Green
        const Color(0xFFFBBF24), // Yellow
        const Color(0xFFF97316), // Orange
        const Color(0xFFEC4899), // Pink
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    paint.shader = gradient;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    // Soft vertical bezier curve
    path.cubicTo(
        size.width, size.height * 0.25,
        0, size.height * 0.75,
        size.width / 2, size.height
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- Redesigned Premium Booking Card ---
class _PremiumBookingCard extends StatelessWidget {
  final RideRequest request;
  final bool isDark;
  const _PremiumBookingCard({required this.request, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final status = _getStatus(request.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (request.rideId != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: request.rideId!)));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  height: 52, width: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [status.color.withOpacity(0.12), status.color.withOpacity(0.04)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: Icon(Icons.bookmark_rounded, color: status.color, size: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ride Booking",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _TripsScreenState.kSecondary, letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Ride from ${request.passengerName}",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : _TripsScreenState.kPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.airline_seat_recline_extra_rounded, size: 12, color: _TripsScreenState.kAccent),
                          const SizedBox(width: 4),
                          Text(
                            "${request.seatsRequested} seat${request.seatsRequested > 1 ? 's' : ''} reserved",
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _TripsScreenState.kSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _StatusBadge(label: status.label, color: status.color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _StatusData _getStatus(String s) {
    switch (s) {
      case 'accepted': return _StatusData("Accepted", const Color(0xFF10B981));
      case 'rejected': return _StatusData("Rejected", const Color(0xFFF43F5E));
      case 'cancelled': return _StatusData("Cancelled", Colors.grey);
      default: return _StatusData("Pending", const Color(0xFFF59E0B));
    }
  }
}

// --- Reusable Mini Components ---
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  const _StatChip(this.icon, this.text, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _TripsScreenState.kSecondary),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : _TripsScreenState.kPrimary)),
      ],
    );
  }
}

class _VehicleIcon extends StatelessWidget {
  final VehicleType type;
  const _VehicleIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final isBike = type == VehicleType.bike;
    return Container(
      height: 48, width: 48,
      decoration: BoxDecoration(
        color: _TripsScreenState.kAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
          isBike ? Icons.two_wheeler_rounded : Icons.directions_car_filled_rounded,
          color: _TripsScreenState.kAccent, size: 24
      ),
    );
  }
}

class _StatusData {
  final String label;
  final Color color;
  _StatusData(this.label, this.color);
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({required this.minHeight, required this.maxHeight, required this.child});
  final double minHeight, maxHeight;
  final Widget child;
  @override double get minExtent => minHeight;
  @override double get maxExtent => maxHeight;
  @override Widget build(context, shrinkOffset, overlapsContent) => SizedBox.expand(child: child);
  @override bool shouldRebuild(_SliverAppBarDelegate old) => maxHeight != old.maxHeight || minHeight != old.minHeight || child != old.child;
}
