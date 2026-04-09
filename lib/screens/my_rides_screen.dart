import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../models/ride_model.dart';
import '../services/firestore_service.dart';
import 'offer_ride_screen.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Premium Design System Tokens ---
  static const Color kAccent = Color(0xFF2E7CF6); // Premium Blue
  static const Color kPrimary = Color(0xFF0F172A); // Slate 900
  static const Color kSecondary = Color(0xFF64748B); // Slate 500
  static const Color kSuccess = Color(0xFF10B981); // Emerald 500
  static const Color kDanger = Color(0xFFF43F5E); // Rose 500
  static const Color kBackground = Color(0xFFF8FAFC); // Slate 50

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
              : constraints.maxWidth > 600 ? 40 : 20;

          return Stack(
            children: [
              if (!isDark) ...[
                _buildAmbientBlob(kAccent.withOpacity(0.06), 300, -100, -100),
                _buildAmbientBlob(kSuccess.withOpacity(0.04), 250, 200, null, right: -80),
              ],
              SafeArea(
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    _buildPremiumSliverAppBar(context, isDark, horizontalPadding),
                    _buildStickyTabBar(isDark, horizontalPadding),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRideList(isDark, 'active', horizontalPadding),
                      _buildRideList(isDark, 'history', horizontalPadding),
                    ],
                  ),
                ),
              ),
              _buildResponsiveFAB(context, constraints.maxWidth),
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
          boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 120, spreadRadius: 60)],
        ),
      ),
    );
  }

  Widget _buildPremiumSliverAppBar(BuildContext context, bool isDark, double horizontalPadding) {
    return SliverAppBar(
      expandedHeight: 180,
      collapsedHeight: 80,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leadingWidth: horizontalPadding + 60,
      leading: Padding(
        padding: EdgeInsets.only(left: horizontalPadding),
        child: Center(
          child: _buildGlassAction(
            Icons.arrow_back_ios_new_rounded, 
            () => Navigator.pop(context), 
            isDark,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding + 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "My Journeys",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 38, fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : kPrimary,
                  letterSpacing: -1.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Track and manage your shared rides",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, color: kSecondary, fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
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
        minHeight: 74, maxHeight: 74,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: isDark ? const Color(0xFF020617).withOpacity(0.85) : kBackground.withOpacity(0.85),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: kAccent.withOpacity(0.12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: kAccent,
                unselectedLabelColor: kSecondary,
                labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [Tab(text: "Live Now"), Tab(text: "Past Offers")],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRideList(bool isDark, String filter, double horizontalPadding) {
    return StreamBuilder<List<Ride>>(
      stream: FirestoreService.getUserRidesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 3));
        }

        final allRides = snapshot.data ?? [];
        final rides = filter == 'active' 
            ? allRides.where((r) => r.status == 'active').toList()
            : allRides.where((r) => r.status != 'active').toList();

        if (rides.isEmpty) return _buildEmptyState(filter, isDark);

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 140),
          physics: const BouncingScrollPhysics(),
          itemCount: rides.length,
          itemBuilder: (context, index) {
            return TweenAnimationBuilder(
              duration: Duration(milliseconds: 500 + (index * 100)),
              tween: Tween<double>(begin: 0, end: 1),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: child,
                ),
              ),
              child: _PremiumRideCard(ride: rides[index], isDark: isDark),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String filter, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 140, width: 140,
            decoration: BoxDecoration(color: kAccent.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(
              filter == 'active' ? Icons.directions_car_rounded : Icons.history_rounded, 
              size: 60, color: kAccent.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            filter == 'active' ? "No Ongoing Offers" : "No Journey History",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22, fontWeight: FontWeight.w800, 
              color: isDark ? Colors.white : kPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              filter == 'active' 
                  ? "Start by offering a ride on your regular route today."
                  : "You haven't completed any ride offers yet.",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: kSecondary, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveFAB(BuildContext context, double width) {
    final bool isExpanded = width > 720;
    return Positioned(
      bottom: 32, left: 0, right: 0,
      child: Center(
        child: Container(
          width: isExpanded ? 280 : width - 48,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kAccent, Color(0xFF1E3A8A)], 
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: kAccent.withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 10)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OfferRideScreen())),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    "Offer New Ride", 
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassAction(IconData icon, VoidCallback onTap, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.white.withOpacity(0.5), 
              width: 1.5,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, size: 18, color: isDark ? Colors.white : kPrimary), 
            onPressed: onTap,
          ),
        ),
      ),
    );
  }
}

class _PremiumRideCard extends StatelessWidget {
  final Ride ride;
  final bool isDark;
  const _PremiumRideCard({required this.ride, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final String date = DateFormat('EEE, MMM dd').format(ride.departureTime);
    final String time = DateFormat('hh:mm a').format(ride.departureTime);
    final bool isActive = ride.status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.white10 : Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(isDark ? 0.4 : 0.08), 
            blurRadius: 40, offset: const Offset(0, 20),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildVehicleIcon(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ride.vehicleModel, 
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18, fontWeight: FontWeight.w800, 
                              color: isDark ? Colors.white : _MyRidesScreenState.kPrimary,
                            ),
                          ),
                          Text(
                            ride.vehicleType.name.toUpperCase(), 
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, fontWeight: FontWeight.w700, 
                              color: _MyRidesScreenState.kSecondary, letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(ride.status),
                  ],
                ),
                const SizedBox(height: 32),
                _buildJourneyLine(),
                const SizedBox(height: 32),
                _buildInfoStrip(date, time),
              ],
            ),
          ),
          if (isActive) _buildActionFooter(context),
        ],
      ),
    );
  }

  Widget _buildVehicleIcon() {
    return Container(
      width: 54, height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _MyRidesScreenState.kAccent.withOpacity(0.12),
            _MyRidesScreenState.kAccent.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        ride.vehicleType == VehicleType.bike 
            ? Icons.two_wheeler_rounded : Icons.directions_car_filled_rounded, 
        color: _MyRidesScreenState.kAccent, size: 24,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color color = status == 'active' ? _MyRidesScreenState.kSuccess : _MyRidesScreenState.kSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
      child: Text(
        status.toUpperCase(), 
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildJourneyLine() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _dot(_MyRidesScreenState.kAccent),
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _MyRidesScreenState.kAccent,
                          _MyRidesScreenState.kDanger.withOpacity(0.5),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                _dot(_MyRidesScreenState.kDanger),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _locationRow("PICKUP", ride.origin),
                const SizedBox(height: 24),
                _locationRow("DESTINATION", ride.destination),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "৳${ride.pricePerSeat.toInt()}", 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28, fontWeight: FontWeight.w900, 
                  color: _MyRidesScreenState.kAccent, letterSpacing: -1,
                ),
              ),
              Text(
                "per seat", 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, fontWeight: FontWeight.w700, color: _MyRidesScreenState.kSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 12, height: 12, 
    decoration: BoxDecoration(
      color: color.withOpacity(0.2), shape: BoxShape.circle, 
      border: Border.all(color: color, width: 2.5),
    ),
  );

  Widget _locationRow(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label, 
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9, fontWeight: FontWeight.w800, 
          color: _MyRidesScreenState.kSecondary, letterSpacing: 1.5,
        ),
      ),
      Text(
        value, maxLines: 1, overflow: TextOverflow.ellipsis, 
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16, fontWeight: FontWeight.w700, 
          color: isDark ? Colors.white : _MyRidesScreenState.kPrimary,
        ),
      ),
    ],
  );

  Widget _buildInfoStrip(String date, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC), 
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _infoItem(Icons.calendar_today_rounded, date),
          _infoItem(Icons.schedule_rounded, time),
          _infoItem(Icons.group_rounded, "${ride.seatsAvailable}/${ride.seatsTotal}"),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: _MyRidesScreenState.kSecondary),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          text, 
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w700, 
            color: isDark ? Colors.white70 : _MyRidesScreenState.kPrimary.withOpacity(0.8),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _buildActionFooter(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF1F5F9).withOpacity(0.4),
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9))),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _actionBtn("Cancel Ride", _MyRidesScreenState.kDanger, Icons.delete_outline_rounded, () => _showCancelDialog(context)),
            VerticalDivider(
              width: 1, thickness: 1, 
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9), 
              indent: 16, endIndent: 16,
            ),
            _actionBtn("Edit Details", _MyRidesScreenState.kAccent, Icons.edit_note_rounded, () {}),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, IconData icon, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label, 
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w800, color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _showCancelDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8 * anim1.value, sigmaY: 8 * anim1.value),
        child: FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: anim1.drive(Tween<double>(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack))),
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              title: Text("Cancel this offer?", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900)),
              content: Text(
                "This will remove the ride from search results immediately. You cannot undo this action.", 
                style: GoogleFonts.plusJakartaSans(color: _MyRidesScreenState.kSecondary, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  child: Text("Nevermind", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _MyRidesScreenState.kSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (ride.id != null) await FirestoreService.cancelRide(ride.id!);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _MyRidesScreenState.kDanger, elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text("Yes, Cancel", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
