import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/ride_model.dart';
import '../widgets/ride_card.dart';

class AvailableRidesScreen extends StatefulWidget {
  const AvailableRidesScreen({super.key});

  @override
  State<AvailableRidesScreen> createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  
  // Dummy rides for initial list and results
  final List<Ride> _allRides = [
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
    Ride(
      driverName: "Tanvir Hasan",
      rating: "4.7",
      vehicleId: "DHAKA-METRO-THA-9012",
      vehicleType: VehicleType.cng,
      vehicleModel: "Bajaj RE",
      origin: "Banani 11",
      destination: "Uttara Sector 7",
      departureTime: DateTime.now().add(const Duration(hours: 1)),
      seatsTotal: 3,
      seatsAvailable: 3,
      pricePerSeat: 150.0,
    ),
  ];

  List<Ride> _filteredRides = [];

  @override
  void initState() {
    super.initState();
    _filteredRides = List.from(_allRides);
  }

  void _filterRides() {
    setState(() {
      _filteredRides = _allRides.where((ride) {
        final matchFrom = _fromController.text.isEmpty || ride.origin.toLowerCase().contains(_fromController.text.toLowerCase());
        final matchTo = _toController.text.isEmpty || ride.destination.toLowerCase().contains(_toController.text.toLowerCase());
        return matchFrom && matchTo;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchSection(),
          Expanded(
            child: _filteredRides.isEmpty 
              ? _buildNoResults()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 30),
                  itemCount: _filteredRides.length,
                  itemBuilder: (context, index) => RideCard(ride: _filteredRides[index]),
                ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        "Available Rides",
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A),
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSearchField(
                  controller: _fromController,
                  hint: "Where from?",
                  icon: Icons.my_location_rounded,
                  color: const Color(0xFF4F46E5),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(height: 24, color: Colors.white, thickness: 1),
                ),
                _buildSearchField(
                  controller: _toController,
                  hint: "Where to?",
                  icon: Icons.location_on_rounded,
                  color: const Color(0xFFFD6B6B),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF64748B)),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('EEE, MMM dd').format(_selectedDate),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _filterRides,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  minimumSize: const Size(100, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: const Icon(Icons.search_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (_) => _filterRides(),
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No rides found",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
