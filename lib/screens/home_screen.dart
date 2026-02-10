import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../widgets/ride_card.dart';
import '../widgets/action_tile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'offer_ride_screen.dart';
import 'available_rides.dart';
import 'notifications_screen.dart';
import 'ongoing_ride_screen.dart';

class RydenHome extends StatefulWidget {
  const RydenHome({super.key});
  @override
  State<RydenHome> createState() => _RydenHomeState();
}

class _RydenHomeState extends State<RydenHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. THE TOP IMAGE HEADER
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 280,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/home-pic.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: _buildTransparentHeader(),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: 20,
                  right: 20,
                  child: _buildSearchBar(),
                ),
              ],
            ),
          ),

          // 2. THE CONTENT AREA
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 40, 0, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionHeader("Quick Actions", false),
                _buildOngoingRideBanner(),
                _buildQuickActionsGrid(),
                const SizedBox(height: 5),
                _sectionHeader("Upcoming Rides", true),
                _buildUpcomingRides(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransparentHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 10, 25, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<UserProfile?>(
              stream: FirestoreService.getUserProfileStream(),
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final displayName = (profile?.displayName.isNotEmpty == true)
                    ? profile!.displayName
                    : (AuthService.currentUser?.email?.split('@').first ?? 'Student');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Welcome back,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
            Row(
              children: [
                _notificationBell(),
                const SizedBox(width: 12),
                _headerIcon(Icons.settings_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerIcon(IconData icon, {int badge = 0}) => Stack(children: [
    Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22)
    ),
    if (badge > 0)
      Positioned(
          right: 0,
          top: 0,
          child: CircleAvatar(
              radius: 8,
              backgroundColor: Colors.redAccent,
              child: Text("$badge", style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))
          )
      ),
  ]);

  Widget _notificationBell() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      },
      child: StreamBuilder<int>(
        stream: FirestoreService.getUnreadNotificationCount(),
        builder: (context, snap) {
          final count = snap.data ?? 0;
          return Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
              ),
              if (count > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOngoingRideBanner() {
    return StreamBuilder<List<Ride>>(
      stream: FirestoreService.getUserRidesStream(),
      builder: (context, driverSnap) {
        return StreamBuilder<List<Ride>>(
          stream: FirestoreService.getMyActiveRidesAsPassenger(),
          builder: (context, passengerSnap) {
            final driverRides = (driverSnap.data ?? [])
                .where((r) => r.status == 'in_progress')
                .toList();
            final passengerRides = passengerSnap.data ?? [];

            final Map<String, Ride> rideMap = {};
            for (final r in [...driverRides, ...passengerRides]) {
              if (r.id != null) rideMap[r.id!] = r;
            }
            final activeRides = rideMap.values.toList();
            final hasRide = activeRides.isNotEmpty;
            final ride = hasRide ? activeRides.first : null;
            final isDriver = ride != null && ride.driverId == AuthService.currentUser?.uid;

            return AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: hasRide ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                child: hasRide
                    ? GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => OngoingRideScreen(rideId: ride!.id!),
                          ));
                        },
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                          padding: const EdgeInsets.all(0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              children: [
                                // Subtle gradient accent
                                Positioned(
                                  right: -30,
                                  top: -30,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          const Color(0xFF10B981).withOpacity(0.25),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: -20,
                                  bottom: -20,
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          const Color(0xFF2E7CF6).withOpacity(0.15),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Content
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          // Live indicator
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: const Color(0xFF10B981).withOpacity(0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TweenAnimationBuilder<double>(
                                                  tween: Tween(begin: 0.3, end: 1.0),
                                                  duration: const Duration(milliseconds: 800),
                                                  builder: (_, value, __) => Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration: BoxDecoration(
                                                      color: Color.lerp(
                                                        const Color(0xFF10B981).withOpacity(0.4),
                                                        const Color(0xFF10B981),
                                                        value,
                                                      ),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color(0xFF10B981).withOpacity(0.5 * value),
                                                          blurRadius: 6,
                                                          spreadRadius: 1,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "LIVE",
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: const Color(0xFF10B981),
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Passenger count chip
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.people_rounded, size: 13, color: Colors.white.withOpacity(0.6)),
                                                const SizedBox(width: 5),
                                                Text(
                                                  "${ride!.passengers.length}",
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white.withOpacity(0.7),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: Colors.white.withOpacity(0.3),
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isDriver ? "Your ride is live" : "Ride in progress",
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFF10B981),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        ride.origin,
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: Colors.white.withOpacity(0.6),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.4),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        ride.destination,
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: Colors.white.withOpacity(0.6),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBar() => GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AvailableRidesScreen()),
      );
    },
    child: Container(
      height: 60,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFF2E7CF6).withOpacity(0.12), blurRadius: 25, offset: const Offset(0, 10))
          ]
      ),
      child: Row(children: [
        const SizedBox(width: 18),
        const Icon(Icons.search_rounded, color: Color(0xFF2E7CF6), size: 26),
        const SizedBox(width: 14),
        const Expanded(
          child: Text("Where are you heading?", style: TextStyle(color: Color(0xFF9BA5B0), fontSize: 15)),
        ),
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF4F7F9), borderRadius: BorderRadius.circular(12)),
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.tune_rounded, color: Color(0xFF2E7CF6), size: 20),
          ),
        ),
      ]),
    ),
  );

  Widget _buildQuickActionsGrid() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Row(children: [
      ActionTile(
        label: "Find", 
        icon: Icons.search_rounded, 
        color: const Color(0xFF2E7CF6),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AvailableRidesScreen()),
          );
        },
      ),
      const SizedBox(width: 12),
      ActionTile(
        label: "Offer", 
        icon: Icons.add_circle_outline, 
        color: const Color(0xFF00BFA5),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const OfferRideScreen()),
          );
        },
      ),
      const SizedBox(width: 12),
      const ActionTile(label: "Group", icon: Icons.groups_rounded, color: Color(0xFFFD6B6B)),
    ]),
  );

  Widget _buildUpcomingRides() {
    return StreamBuilder<List<Ride>>(
      stream: FirestoreService.getAvailableRidesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7CF6)),
            ),
          );
        }

        final rides = snapshot.data ?? [];

        if (rides.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.directions_car_outlined, size: 50, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    "No rides available yet",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Be the first to offer a ride!",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Show up to 5 most recent rides on home
        final displayRides = rides.take(5).toList();
        return Column(
          children: displayRides.map((ride) => RideCard(ride: ride)).toList(),
        );
      },
    );
  }

  Widget _sectionHeader(String title, bool showAll) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        if (showAll) 
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AvailableRidesScreen()),
              );
            },
            child: const Text("See All", style: TextStyle(color: Color(0xFF2E7CF6), fontWeight: FontWeight.bold)),
          ),
      ],
    ),
  );
}
