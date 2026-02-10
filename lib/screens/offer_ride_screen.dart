import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ride_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

enum GenderPreference { both, male, female }

class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  // State Variables
  VehicleType _selectedVehicle = VehicleType.car;
  GenderPreference _genderPreference = GenderPreference.male;
  int _seatsAvailable = 3;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _instantBooking = false;
  bool _isPublishing = false;

  // Route Management
  final List<TextEditingController> _locations = [
    TextEditingController(), // Pickup
    TextEditingController(), // Drop-off
  ];

  late TextEditingController _priceController;

  // Design Constants - Refined Palette
  final Color kPrimaryColor = const Color(0xFF4F46E5);
  final Color kBackgroundColor = const Color(0xFFF8FAFC);
  final Color kSurfaceColor = Colors.white;
  final Color kTextPrimary = const Color(0xFF0F172A);
  final Color kTextSecondary = const Color(0xFF64748B);
  final Color kAccentRed = const Color(0xFFEF4444);
  final Color kAccentAmber = const Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: "50");
  }

  @override
  void dispose() {
    _priceController.dispose();
    for (var c in _locations) {
      c.dispose();
    }
    super.dispose();
  }

  void _vibrate() => HapticFeedback.selectionClick();

  void _addStop() {
    if (_locations.length < 5) {
      _vibrate();
      setState(() {
        _locations.insert(_locations.length - 1, TextEditingController());
      });
    }
  }

  void _removeStop(int index) {
    _vibrate();
    setState(() {
      _locations[index].dispose();
      _locations.removeAt(index);
    });
  }

  Future<void> _publishRide() async {
    final origin = _locations.first.text.trim();
    final destination = _locations.last.text.trim();

    if (origin.isEmpty || destination.isEmpty) {
      _showSnackBar('Please enter pickup and drop-off locations.', false);
      return;
    }

    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      _showSnackBar('Please sign in to publish a ride.', false);
      return;
    }

    setState(() => _isPublishing = true);

    // Collect stops (intermediate locations)
    final stops = <String>[];
    for (int i = 1; i < _locations.length - 1; i++) {
      final stop = _locations[i].text.trim();
      if (stop.isNotEmpty) stops.add(stop);
    }

    // Build departure DateTime
    final departure = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Get proper display name from Firestore
    final profile = await FirestoreService.getUserProfile(uid);
    final driverName = (profile?.displayName.isNotEmpty == true)
        ? profile!.displayName
        : (AuthService.currentUser?.displayName ??
            AuthService.currentUser?.email?.split('@').first ??
            'Unknown');

    final ride = Ride(
      driverId: uid,
      driverName: driverName,
      vehicleId: '',
      vehicleType: _selectedVehicle,
      vehicleModel: _getVehicleName(_selectedVehicle),
      origin: origin,
      destination: destination,
      stops: stops,
      departureTime: departure,
      seatsTotal: _seatsAvailable,
      seatsAvailable: _seatsAvailable,
      genderPreference: _genderPreference.name,
      pricePerSeat: double.tryParse(_priceController.text) ?? 50.0,
      instantMatch: _instantBooking,
    );

    final result = await FirestoreService.publishRide(ride);

    setState(() => _isPublishing = false);

    if (mounted) {
      _showSnackBar(result.message, result.success);
      if (result.success) {
        Navigator.pop(context);
      }
    }
  }

  void _showSnackBar(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: kPrimaryColor,
        scaffoldBackgroundColor: kBackgroundColor,
      ),
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepIndicator(),
                      const SizedBox(height: 25),
                      
                      _sectionLabel("ITINERARY"),
                      _buildRouteCard(),
                      
                      const SizedBox(height: 20),
                      
                      _sectionLabel("DATE & TRANSPORT"),
                      _buildDetailsGrid(),
                      
                      const SizedBox(height: 20),
                      
                      _sectionLabel("PREFERENCES & COST"),
                      _buildPreferencesCard(),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              _buildBottomAction(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepCircle("1", "Route", true),
        _stepLine(true),
        _stepCircle("2", "Details", true),
        _stepLine(false),
        _stepCircle("3", "Publish", false),
      ],
    );
  }

  Widget _stepCircle(String step, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? kPrimaryColor : const Color(0xFFE2E8F0),
            shape: BoxShape.circle,
            boxShadow: active ? [
              BoxShadow(
                color: kPrimaryColor.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Center(
            child: Text(
              step,
              style: TextStyle(
                color: active ? Colors.white : kTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? kPrimaryColor : kTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2.5,
        margin: const EdgeInsets.only(bottom: 18, left: 8, right: 8),
        decoration: BoxDecoration(
          color: active ? kPrimaryColor : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: kTextSecondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _locations.length,
              itemBuilder: (context, index) {
                final isFirst = index == 0;
                final isLast = index == _locations.length - 1;
                return _buildLocationInputRow(index, isFirst, isLast);
              },
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 20, endIndent: 20),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _addStop,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 20, color: kPrimaryColor),
                    const SizedBox(width: 8),
                    Text(
                      "Add a Stopover",
                      style: GoogleFonts.plusJakartaSans(
                        color: kPrimaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
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

  Widget _buildLocationInputRow(int index, bool isFirst, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 12),
            _locationMarker(isFirst ? kPrimaryColor : (isLast ? kAccentRed : kAccentAmber)),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isFirst ? kPrimaryColor : kAccentAmber,
                      (index + 1 == _locations.length - 1) ? kAccentRed : kAccentAmber,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              TextField(
                controller: _locations[index],
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600, 
                  fontSize: 15,
                  color: kTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: isFirst ? "Where from?" : (isLast ? "Where to?" : "Stopover location"),
                  hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 15, fontWeight: FontWeight.w500),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              if (!isLast) const SizedBox(height: 12),
            ],
          ),
        ),
        if (!isFirst && !isLast)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton(
              icon: Icon(Icons.cancel_outlined, color: Colors.grey.shade300, size: 20),
              onPressed: () => _removeStop(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
      ],
    );
  }

  Widget _locationMarker(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 4,
                spreadRadius: 0.5,
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsGrid() {
    return Row(
      children: [
        Expanded(child: _buildInfoCard("Date", DateFormat('EEE, Feb dd').format(_selectedDate), Icons.calendar_month_rounded, _pickDate)),
        const SizedBox(width: 12),
        Expanded(child: _buildInfoCard("Time", _selectedTime.format(context), Icons.access_time_rounded, _pickTime)),
        const SizedBox(width: 12),
        Expanded(child: _buildInfoCard("Vehicle", _getVehicleName(_selectedVehicle), Icons.directions_car_filled_rounded, _showVehicleSelector)),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.06), 
                borderRadius: BorderRadius.circular(10)
              ),
              child: Icon(icon, size: 18, color: kPrimaryColor),
            ),
            const SizedBox(height: 12),
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: kTextPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.bolt_rounded, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Instant Booking", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: kTextPrimary)),
                    Text("Passengers can book without approval", style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _instantBooking,
                onChanged: (v) => setState(() => _instantBooking = v),
                activeColor: kPrimaryColor,
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Gender Preference", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: kTextPrimary)),
                    const SizedBox(height: 10),
                    _buildGenderSelector(),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Seat Price", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: kTextPrimary)),
                  const SizedBox(height: 10),
                  _buildPriceField(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      height: 44,
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _genderBtn(GenderPreference.both, Icons.group_rounded),
          _genderBtn(GenderPreference.male, Icons.male_rounded),
          _genderBtn(GenderPreference.female, Icons.female_rounded),
        ],
      ),
    );
  }

  Widget _genderBtn(GenderPreference g, IconData icon) {
    final active = _genderPreference == g;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _genderPreference = g),
        child: Container(
          decoration: BoxDecoration(
            color: active ? kPrimaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active ? [
              BoxShadow(
                color: kPrimaryColor.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Center(child: Icon(icon, size: 18, color: active ? Colors.white : kTextSecondary)),
        ),
      ),
    );
  }

  Widget _buildPriceField() {
    return Container(
      width: 110,
      height: 44,
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Text("৳", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(18)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _miniBtn(Icons.remove, () => _updateSeats(-1)),
                SizedBox(
                  width: 40, 
                  child: Center(
                    child: Text(
                      "$_seatsAvailable", 
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: kTextPrimary)
                    )
                  )
                ),
                _miniBtn(Icons.add, () => _updateSeats(1)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isPublishing ? null : _publishRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 58),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: _isPublishing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text("Publish Ride", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
        ),
        child: Icon(icon, size: 18, color: kTextPrimary),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: kSurfaceColor,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1E293B).withOpacity(0.06), 
          blurRadius: 24, 
          offset: const Offset(0, 8)
        )
      ],
    );
  }

  void _updateSeats(int d) {
    int n = _seatsAvailable + d;
    if (n >= 1 && n <= 4) setState(() => _seatsAvailable = n);
  }

  String _getVehicleName(VehicleType t) => t == VehicleType.car ? "Car" : (t == VehicleType.bike ? "Bike" : "CNG");

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _selectedTime);
    if (t != null) setState(() => _selectedTime = t);
  }

  void _showVehicleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select Vehicle",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 24),
            _buildVehicleOption(VehicleType.car, "Car", Icons.directions_car_filled_rounded),
            const SizedBox(height: 12),
            _buildVehicleOption(VehicleType.bike, "Bike", Icons.two_wheeler_rounded),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleOption(VehicleType type, String name, IconData icon) {
    final isSelected = _selectedVehicle == type;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedVehicle = type);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withOpacity(0.05) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? kPrimaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : kTextSecondary, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected ? kPrimaryColor : kTextPrimary,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 22),
          ],
        ),
      ),
    );
  }
}
