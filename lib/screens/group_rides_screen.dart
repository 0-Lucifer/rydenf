import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'host_group_ride_screen.dart';
import 'group_ride_card_details.dart';

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
  bool _isLoading = true;

  // Premium Theme Palette
  static const Color kPrimaryBlue = Color(0xFF2E7CF6);
  static const Color kContentColor = Color(0xFF0F172A);
  static const Color kSecondaryText = Color(0xFF64748B);
  static const Color kBgColor = Color(0xFFF8FAFC);
  static const Color kSuccessGreen = Color(0xFF10B981);
  static const Color kBorderColor = Color(0xFFE2E8F0);

  final List<Map<String, dynamic>> _mockRides = [
    {
      "from": "NSU Campus Gate",
      "to": "Banani 11",
      "time": "Today, 5:30 PM",
      "seatsLeft": 2,
      "host": "Aisha",
      "rating": 4.9,
      "gender": "Women",
      "transport": "Uber/pathao",
      "isFull": false,
      "isVerified": true,
      "notes": "Looking for fellow students to share a ride. Please be on time!",
    },
    {
      "from": "AIUB Campus",
      "to": "Uttara House Building",
      "time": "Today, 6:15 PM",
      "seatsLeft": 1,
      "host": "Rafiq",
      "rating": 4.7,
      "gender": "Any",
      "transport": "CNG",
      "isFull": false,
      "isVerified": true,
    },
    {
      "from": "Bashundhara R/A",
      "to": "Dhanmondi 27",
      "time": "Today, 5:45 PM",
      "seatsLeft": 0,
      "host": "Tanvir",
      "rating": 4.8,
      "gender": "Men",
      "transport": "Rickshaw",
      "isFull": true,
      "isVerified": false,
    },
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _swapLocations() {
    String temp = _fromController.text;
    setState(() {
      _fromController.text = _toController.text;
      _toController.text = temp;
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text("Select Transport",
                style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: kContentColor)),
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
      onTap: () {
        setState(() => _selectedTransport = mode);
        Navigator.pop(context);
      },
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
              decoration:
              BoxDecoration(color: isSelected ? kPrimaryBlue : Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: isSelected ? Colors.white : kSecondaryText, size: 20),
            ),
            const SizedBox(width: 16),
            Text(mode,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, fontSize: 15, color: isSelected ? kPrimaryBlue : kContentColor)),
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text("Gender Preference",
                style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: kContentColor)),
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
      onTap: () {
        setState(() => _selectedGender = gender);
        Navigator.pop(context);
      },
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
              decoration:
              BoxDecoration(color: isSelected ? kPrimaryBlue : Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: isSelected ? Colors.white : kSecondaryText, size: 20),
            ),
            const SizedBox(width: 16),
            Text(gender,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, fontSize: 15, color: isSelected ? kPrimaryBlue : kContentColor)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: kPrimaryBlue, size: 22),
          ],
        ),
      ),
    );
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
                _buildSearchCard(),
                const SizedBox(height: 32),
                _buildSectionTitle(),
                _isLoading ? _buildSkeletonList() : _buildRideList(),
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
        IconButton(icon: const Icon(Icons.tune_rounded, color: kContentColor), onPressed: () {}),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchCard() {
    String formattedDate =
    DateUtils.isSameDay(_selectedDate, DateTime.now()) ? "Today" : DateFormat('MMM dd').format(_selectedDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          // 1. Route Input Section (From & To)
          Stack(
            alignment: Alignment.centerRight,
            children: [
              Column(
                children: [
                  _buildSearchInput(
                      controller: _fromController,
                      placeholder: "From (e.g. NSU Gate)",
                      icon: Icons.my_location_rounded,
                      iconColor: kPrimaryBlue),
                  const Padding(padding: EdgeInsets.only(left: 44), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                  _buildSearchInput(
                      controller: _toController,
                      placeholder: "To (e.g. Banani)",
                      icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFFEF4444)),
                ],
              ),
              // Swap Button
              Positioned(
                right: 0,
                child: GestureDetector(
                  onTap: _swapLocations,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
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

          // 2. Badges Row (Date, Transport, Gender)
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

          // 3. Action Button
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: Text("Find Group Rides",
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.2)),
            ),
          ),
        ],
      ),
    );
  }

  // Supporting Helper Widget for Inputs
  Widget _buildSearchInput(
      {required TextEditingController controller,
        required String placeholder,
        required IconData icon,
        required Color iconColor}) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w500),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
            style:
            GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF0F172A)),
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
            Flexible(
                child: Text(text,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w700, color: kContentColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
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
          Text("Available for you",
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: kContentColor)),
          Text("See All", style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: kPrimaryBlue)),
        ],
      ),
    );
  }

  Widget _buildRideList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _mockRides.length,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemBuilder: (context, index) {
        final ride = _mockRides[index];
        return _PremiumRideCard(ride: ride);
      },
    );
  }

  Widget _buildSkeletonList() {
    return Column(
        children: List.generate(
            2,
                (i) => Container(
                margin: const EdgeInsets.all(20),
                height: 180,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)))));
  }

  Widget _buildFab() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kBgColor.withOpacity(0), kBgColor, kBgColor])),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const HostGroupRideScreen()));
        },
        icon: const Icon(Icons.add_circle_rounded, size: 24),
        label: Text("Host a Group Ride", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          elevation: 12,
          shadowColor: kPrimaryBlue.withOpacity(0.3),
        ),
      ),
    );
  }
}

class _PremiumRideCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  const _PremiumRideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final bool isFull = ride['isFull'] ?? false;
    const Color kPrimaryBlue = Color(0xFF2E7CF6);
    const Color kContentColor = Color(0xFF0F172A);
    const Color kSecondaryText = Color(0xFF64748B);
    const Color kBorderColor = Color(0xFFE2E8F0);
    const Color kSuccessGreen = Color(0xFF10B981);

    final IconData genderIcon = ride['gender'] == 'Women'
        ? Icons.female_rounded
        : (ride['gender'] == 'Men' ? Icons.male_rounded : Icons.wc_rounded);

    return GestureDetector(
      onTap: () {
        showGroupRideDetails(context, ride);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                    radius: 20,
                    backgroundColor: kPrimaryBlue.withOpacity(0.1),
                    child: Text(ride['host'][0],
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: kPrimaryBlue))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(ride['host'],
                          style:
                          GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: kContentColor)),
                      if (ride['isVerified'])
                        const Padding(
                            padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified_rounded, size: 16, color: kPrimaryBlue)),
                    ]),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)), // Amber star
                        const SizedBox(width: 4),
                        Text("${ride['rating']}",
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600, fontSize: 13, color: kSecondaryText)),
                        const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.circle, size: 4, color: kSecondaryText)),
                        Icon(genderIcon, size: 14, color: kSecondaryText),
                        const SizedBox(width: 4),
                        Text(ride['gender'],
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600, fontSize: 13, color: kSecondaryText)),
                      ],
                    ),
                  ]),
                ),
                _buildSeatsBadge(isFull, ride['seatsLeft']),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ride['from'],
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700, fontSize: 14, color: kContentColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      Text(ride['to'],
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700, fontSize: 14, color: kContentColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(ride['time'],
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: kPrimaryBlue)),
                    const SizedBox(height: 12),
                    Text(ride['transport'],
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600, fontSize: 11, color: kSecondaryText)),
                  ],
                ),
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
