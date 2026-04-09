import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../widgets/premium_pickers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_ride_model.dart';
import '../services/firestore_service.dart';
import 'host_group_ride_screen.dart';
import 'group_ride_card_details.dart';
import 'group_ride_requests_screen.dart';

class GroupRidesScreen extends StatefulWidget {
  const GroupRidesScreen({super.key});

  @override
  State<GroupRidesScreen> createState() => _GroupRidesScreenState();
}

class _GroupRidesScreenState extends State<GroupRidesScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  String _selectedGender = 'Any';
  String _selectedTransport = 'Uber/Pathao';
  DateTime _selectedDate = DateTime.now();

  List<GroupRide>? _searchResults;
  bool _isSearching = false;

  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;

  static const Color kPrimaryBlue = Color(0xFF2E7CF6);
  static const Color kContentColor = Color(0xFF0F172A);
  static const Color kSecondaryText = Color(0xFF64748B);
  static const Color kBgColor = Color(0xFFF8FAFC);
  static const Color kSuccessGreen = Color(0xFF10B981);
  static const Color kBorderColor = Color(0xFFE2E8F0);

  void _swapLocations() {
    String temp = _fromController.text;
    setState(() {
      _fromController.text = _toController.text;
      _toController.text = temp;
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await PremiumPickers.pickDate(
      context,
      initialDate: _selectedDate,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _pickTransport() {
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
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text("Select Transport", style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: kContentColor)),
            const SizedBox(height: 24),
            _buildTransportOption('Uber/Pathao', Icons.local_taxi_rounded),
            _buildTransportOption('CNG', Icons.minor_crash_rounded),
            _buildTransportOption('Rickshaw', Icons.pedal_bike_rounded),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportOption(String mode, IconData icon) {
    bool isSelected = _selectedTransport == mode;
    return GestureDetector(
      onTap: () { setState(() => _selectedTransport = mode); Navigator.pop(context); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryBlue.withOpacity(0.05) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? kPrimaryBlue : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: isSelected ? kPrimaryBlue : Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: isSelected ? Colors.white : kSecondaryText, size: 20),
            ),
            const SizedBox(width: 16),
            Text(mode, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15, color: isSelected ? kPrimaryBlue : kContentColor)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: kPrimaryBlue, size: 22),
          ],
        ),
      ),
    );
  }

  void _pickGender() {
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
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text("Gender Preference", style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: kContentColor)),
            const SizedBox(height: 24),
            _buildGenderOption('Any', Icons.wc_rounded),
            _buildGenderOption('Women', Icons.female_rounded),
            _buildGenderOption('Men', Icons.male_rounded),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderOption(String gender, IconData icon) {
    bool isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () { setState(() => _selectedGender = gender); Navigator.pop(context); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryBlue.withOpacity(0.05) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? kPrimaryBlue : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: isSelected ? kPrimaryBlue : Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: isSelected ? Colors.white : kSecondaryText, size: 20),
            ),
            const SizedBox(width: 16),
            Text(gender, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15, color: isSelected ? kPrimaryBlue : kContentColor)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: kPrimaryBlue, size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSearch() async {
    setState(() => _isSearching = true);
    final results = await FirestoreService.searchGroupRides(
      from: _fromController.text.trim().isEmpty ? null : _fromController.text.trim(),
      to: _toController.text.trim().isEmpty ? null : _toController.text.trim(),
      date: _selectedDate,
      transport: _selectedTransport,
      gender: _selectedGender,
    );
    if (mounted) setState(() { _searchResults = results; _isSearching = false; });
  }

  void _clearSearch() {
    setState(() {
      _searchResults = null;
      _fromController.clear();
      _toController.clear();
      _selectedGender = 'Any';
      _selectedTransport = 'Uber/Pathao';
      _selectedDate = DateTime.now();
    });
  }

  void _hostNewGroup() async {
    final hasActive = await FirestoreService.hasActiveGroupRide();
    if (!mounted) return;

    if (hasActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You already have an active group ride. Delete it first to create a new one.",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => const HostGroupRideScreen()));
  }

  void _deleteRide(GroupRide ride) async {
    final result = await FirestoreService.deleteGroupRide(ride.id!);
    if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 70),
                _buildMyGroupWidget(),
                _buildSearchCard(),
                const SizedBox(height: 32),
                _buildSectionTitle(),
                _buildRideContent(),
                const SizedBox(height: 120),
              ],
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildFab()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.9),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kContentColor, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text("Group Rides",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: kContentColor)),
      actions: [
        if (_searchResults != null)
          IconButton(icon: const Icon(Icons.close_rounded, color: kContentColor), onPressed: _clearSearch, tooltip: 'Clear search'),
        const SizedBox(width: 8),
      ],
    );
  }

  // ─── My Group Widget ─────────────────────────────────
  Widget _buildMyGroupWidget() {
    return StreamBuilder<List<GroupRide>>(
      stream: FirestoreService.getUserGroupRidesStream(),
      builder: (context, snapshot) {
        final myRides = (snapshot.data ?? [])
            .where((r) => r.status == 'active' || r.status == 'full')
            .toList();

        if (myRides.isEmpty) return const SizedBox.shrink();

        final ride = myRides.first;
        final dep = ride.departureTime;
        final now = DateTime.now();
        String timeText;
        if (dep.year == now.year && dep.month == now.month && dep.day == now.day) {
          timeText = "Today, ${DateFormat('h:mm a').format(dep)}";
        } else {
          timeText = DateFormat('MMM dd, h:mm a').format(dep);
        }

        return Dismissible(
          key: Key(ride.id ?? 'my-ride'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text("Delete Group Ride?", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
                content: Text("This will permanently delete your group ride and all join requests.",
                    style: GoogleFonts.plusJakartaSans(color: kSecondaryText)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ) ?? false;
          },
          onDismissed: (_) => _deleteRide(ride),
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.centerRight,
            child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimaryBlue, kPrimaryBlue.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: kPrimaryBlue.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text("MY GROUP",
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ride.isFull ? Colors.redAccent.withOpacity(0.3) : kSuccessGreen.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        ride.isFull ? "Full" : "${ride.seatsAvailable} seats left",
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.radio_button_checked_rounded, size: 12, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(child: Text(ride.from, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Container(width: 1.5, height: 12, color: Colors.white30),
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 12, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(child: Text(ride.to, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: Colors.white.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text(timeText, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.8))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => GroupRideRequestsScreen(ride: ride)));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_alt_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text("Requests", style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Swipe hint
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text("← Swipe left to delete",
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchCard() {
    String formattedDate = DateUtils.isSameDay(_selectedDate, DateTime.now()) ? "Today" : DateFormat('MMM dd').format(_selectedDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.centerRight,
            children: [
              Column(
                children: [
                  _buildSearchInput(controller: _fromController, placeholder: "From (e.g. NSU Gate)", icon: Icons.my_location_rounded, iconColor: kPrimaryBlue),
                  const Padding(padding: EdgeInsets.only(left: 44), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                  _buildSearchInput(controller: _toController, placeholder: "To (e.g. Banani)", icon: Icons.location_on_rounded, iconColor: const Color(0xFFEF4444)),
                ],
              ),
              Positioned(
                right: 0,
                child: GestureDetector(
                  onTap: _swapLocations,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC), shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.swap_vert_rounded, size: 20, color: kPrimaryBlue),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(flex: 3, child: _buildInteractiveBadge(Icons.calendar_today_rounded, formattedDate, _pickDate)),
              const SizedBox(width: 8),
              Expanded(flex: 4, child: _buildInteractiveBadge(Icons.commute_rounded, _selectedTransport, _pickTransport)),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _buildInteractiveBadge(Icons.wc_rounded, _selectedGender, _pickGender)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 58,
            child: ElevatedButton(
              onPressed: _isSearching ? null : _handleSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0,
              ),
              child: _isSearching
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : Text("Find Group Rides", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInput({required TextEditingController controller, required String placeholder, required IconData icon, required Color iconColor}) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w500),
              border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15, color: kContentColor),
          ),
        ),
      ],
    );
  }



  Widget _buildInteractiveBadge(IconData icon, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorderColor)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: kPrimaryBlue),
            const SizedBox(width: 6),
            Flexible(child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: kContentColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_searchResults != null ? "Search Results" : "Available for you",
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: kContentColor)),
          if (_searchResults != null)
            GestureDetector(
              onTap: _clearSearch,
              child: Text("Clear", style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: kPrimaryBlue)),
            ),
        ],
      ),
    );
  }

  Widget _buildRideContent() {
    if (_searchResults != null) return _buildRideListFromData(_searchResults!);

    return StreamBuilder<List<GroupRide>>(
      stream: FirestoreService.getAvailableGroupRidesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _buildSkeletonList();
        final rides = snapshot.data ?? [];
        // Filter out user's own rides (shown in My Group widget above)
        final otherRides = rides.where((r) => r.hostId != _myUid).toList();
        if (otherRides.isEmpty) return _buildEmptyState();
        return _buildRideListFromData(otherRides);
      },
    );
  }

  Widget _buildRideListFromData(List<GroupRide> rides) {
    if (rides.isEmpty) return _buildEmptyState();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rides.length,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemBuilder: (context, index) => _PremiumRideCard(ride: rides[index]),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.groups_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _searchResults != null ? "No rides match your search" : "No group rides available",
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 6),
            Text(
              _searchResults != null ? "Try adjusting your filters" : "Be the first to host a group ride!",
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(2, (i) => Container(
        margin: const EdgeInsets.all(20), height: 180,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      )),
    );
  }

  Widget _buildFab() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kBgColor.withOpacity(0), kBgColor, kBgColor]),
      ),
      child: ElevatedButton.icon(
        onPressed: _hostNewGroup,
        icon: const Icon(Icons.add_circle_rounded, size: 24),
        label: Text("Host a Group Ride", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue, foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          elevation: 12, shadowColor: kPrimaryBlue.withOpacity(0.3),
        ),
      ),
    );
  }
}

class _PremiumRideCard extends StatelessWidget {
  final GroupRide ride;
  const _PremiumRideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final bool isFull = ride.isFull;
    const Color kPrimaryBlue = Color(0xFF2E7CF6);
    const Color kContentColor = Color(0xFF0F172A);
    const Color kSecondaryText = Color(0xFF64748B);
    const Color kBorderColor = Color(0xFFE2E8F0);

    final IconData genderIcon = ride.gender == 'Women' ? Icons.female_rounded : (ride.gender == 'Men' ? Icons.male_rounded : Icons.wc_rounded);

    final now = DateTime.now();
    final dep = ride.departureTime;
    String timeText;
    if (dep.year == now.year && dep.month == now.month && dep.day == now.day) {
      timeText = "Today, ${DateFormat('h:mm a').format(dep)}";
    } else if (dep.year == now.year && dep.month == now.month && dep.day == now.day + 1) {
      timeText = "Tomorrow, ${DateFormat('h:mm a').format(dep)}";
    } else {
      timeText = DateFormat('MMM dd, h:mm a').format(dep);
    }

    return GestureDetector(
      onTap: () => showGroupRideDetails(context, ride),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white),
          boxShadow: [BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20, backgroundColor: kPrimaryBlue.withOpacity(0.1),
                  child: Text(ride.hostName.isNotEmpty ? ride.hostName[0] : '?',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: kPrimaryBlue)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(ride.hostName.isNotEmpty ? ride.hostName : 'Unknown',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: kContentColor)),
                      ),
                      if (ride.isVerified)
                        const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified_rounded, size: 16, color: kPrimaryBlue)),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 4),
                      Text("${ride.hostRating}", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: kSecondaryText)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.circle, size: 4, color: kSecondaryText)),
                      Icon(genderIcon, size: 14, color: kSecondaryText),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(ride.gender, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: kSecondaryText)),
                      ),
                    ]),
                  ]),
                ),
                _buildSeatsBadge(isFull, ride.seatsAvailable),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: kBorderColor)),
            Row(
              children: [
                Column(children: [
                  const Icon(Icons.radio_button_checked_rounded, size: 14, color: kPrimaryBlue),
                  Container(width: 1.5, height: 24, color: kBorderColor),
                  const Icon(Icons.location_on_rounded, size: 14, color: Colors.redAccent),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ride.from, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: kContentColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Text(ride.to, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: kContentColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(timeText, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: kPrimaryBlue)),
                  const SizedBox(height: 12),
                  Text(ride.transport, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 11, color: kSecondaryText)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatsBadge(bool isFull, int seats) {
    const Color kSuccessGreen = Color(0xFF10B981);
    final Color color = isFull ? Colors.redAccent : kSuccessGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(isFull ? "Full" : "$seats seats",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 11, color: color)),
    );
  }
}
