import 'package:flutter/material.dart';
import '../models/ride_model.dart';
import '../widgets/ride_card.dart';
import '../widgets/action_tile.dart';
import 'offer_ride_screen.dart';
import 'available_rides.dart';

class RydenHome extends StatefulWidget {
  const RydenHome({super.key});
  @override
  State<RydenHome> createState() => _RydenHomeState();
}

class _RydenHomeState extends State<RydenHome> {
  final List<Ride> upcomingRides = [
    Ride(
      driverName: "Sarah Ahmed",
      rating: "4.9",
      vehicleId: "DHAKA-METRO-KA-1234",
      vehicleType: VehicleType.bike,
      vehicleModel: "Yamaha R15",
      origin: "NSU Campus Gate",
      destination: "Bashundhara City",
      departureTime: DateTime.now().add(const Duration(hours: 2)),
      seatsTotal: 1,
      seatsAvailable: 1,
      pricePerSeat: 120.0,
    ),
    Ride(
      driverName: "Rafiqul Islam",
      rating: "4.8",
      vehicleId: "DHAKA-METRO-GA-5678",
      vehicleType: VehicleType.car,
      vehicleModel: "Toyota Corolla",
      origin: "Gulshan 2 Circle",
      destination: "Dhanmondi 27",
      departureTime: DateTime.now().add(const Duration(hours: 4, minutes: 15)),
      seatsTotal: 4,
      seatsAvailable: 2,
      pricePerSeat: 180.0,
    ),
  ];

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
            padding: const EdgeInsets.fromLTRB(0, 40, 0, 100), // Reduced top padding from 50 to 40
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionHeader("Quick Actions", false),
                _buildQuickActionsGrid(),
                const SizedBox(height: 5),
                _sectionHeader("Upcoming Rides", true),
                ...upcomingRides.map((ride) => RideCard(ride: ride)),
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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Welcome back,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(
                  "2212302642",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _headerIcon(Icons.notifications_none_rounded, badge: 2),
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

  Widget _sectionHeader(String title, bool showAll) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        if (showAll) const Text("See All", style: TextStyle(color: Color(0xFF2E7CF6), fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
