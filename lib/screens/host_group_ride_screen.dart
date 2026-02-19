import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HostGroupRideScreen extends StatefulWidget {
  const HostGroupRideScreen({super.key});

  @override
  State<HostGroupRideScreen> createState() => _HostGroupRideScreenState();
}

class _HostGroupRideScreenState extends State<HostGroupRideScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form State
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  String _selectedTransport = 'Uber/Pathao';
  String _selectedGender = 'Any';
  int _seatsAvailable = 2;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 17, minute: 30);
  final TextEditingController _notesController = TextEditingController();

  // Premium Theme Palette
  static const Color kPrimaryBlue = Color(0xFF2E7CF6);
  static const Color kContentColor = Color(0xFF0F172A);
  static const Color kSecondaryText = Color(0xFF64748B);
  static const Color kBgColor = Color(0xFFF8FAFC);
  static const Color kBorderColor = Color(0xFFE2E8F0);

  final List<String> _transportOptions = ['Uber/Pathao', 'CNG', 'Rickshaw'];
  final List<String> _genderOptions = ['Any', 'Men', 'Women'];

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    } else {
      _handlePublish();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _handlePublish() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const CircularProgressIndicator(color: kPrimaryBlue, strokeWidth: 3),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    Navigator.pop(context); // Pop loading
    Navigator.pop(context); // Go back

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Ride hosted successfully!", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeBg = isDark ? const Color(0xFF0F172A) : kBgColor;

    return Scaffold(
      backgroundColor: themeBg,
      appBar: _buildAppBar(isDark),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            children: [
              _buildStepIndicator(isDark),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentStep = i),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildRouteStep(isDark),
                    _buildTransportStep(isDark),
                    _buildFinalStep(isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActions(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 80,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Center(
          child: Material(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _previousStep,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white10 : kBorderColor),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : kContentColor, size: 18),
              ),
            ),
          ),
        ),
      ),
      title: Text(
        "Host Ride",
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : kContentColor),
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: List.generate(3, (index) {
          bool isActive = index <= _currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
              decoration: BoxDecoration(
                color: isActive ? kPrimaryBlue : (isDark ? Colors.white10 : kBorderColor),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRouteStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderLabel("Where are you heading?", "Provide your pickup and destination points."),
          const SizedBox(height: 32),
          _buildFormCard(
            isDark,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      const Icon(Icons.radio_button_checked_rounded, color: kPrimaryBlue, size: 22),
                      Expanded(
                        child: Container(
                          width: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: isDark ? Colors.white10 : kBorderColor,
                        ),
                      ),
                      const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 22),
                      const SizedBox(height: 12),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRouteInputField(
                          controller: _fromController,
                          label: "Pickup Location",
                          hint: "e.g. NSU Main Gate",
                          isDark: isDark,
                        ),
                        Divider(height: 1, color: isDark ? Colors.white10 : kBorderColor),
                        _buildRouteInputField(
                          controller: _toController,
                          label: "Destination",
                          hint: "e.g. Banani 11",
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, 
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11, 
              fontWeight: FontWeight.w800, 
              color: kSecondaryText, 
              letterSpacing: 0.5
            )
          ),
          TextField(
            controller: controller,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, 
              fontSize: 16, 
              color: isDark ? Colors.white : kContentColor
            ),
            decoration: InputDecoration(
              hintText: hint, 
              hintStyle: TextStyle(color: kSecondaryText.withOpacity(0.3)), 
              border: InputBorder.none, 
              isDense: true, 
              contentPadding: const EdgeInsets.symmetric(vertical: 8)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderLabel("Preferences", "Choose how you want to travel"),
          const SizedBox(height: 32),
          Text("Transport Mode", style: _sectionStyle(isDark)),
          const SizedBox(height: 16),
          Row(
            children: _transportOptions.map((mode) {
              bool isSelected = _selectedTransport == mode;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTransport = mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: isSelected ? kPrimaryBlue : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? kPrimaryBlue : (isDark ? Colors.white10 : kBorderColor)),
                      boxShadow: isSelected ? [BoxShadow(color: kPrimaryBlue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          mode == 'Rickshaw' ? Icons.pedal_bike_rounded : (mode == 'CNG' ? Icons.minor_crash_rounded : Icons.local_taxi_rounded),
                          color: isSelected ? Colors.white : kSecondaryText,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          mode,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : (isDark ? Colors.white70 : kContentColor)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Text("Seats Available", style: _sectionStyle(isDark)),
          const SizedBox(height: 16),
          _buildFormCard(
            isDark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSeatControl(Icons.remove_rounded, () { if(_seatsAvailable > 1) setState(() => _seatsAvailable--); }, isDark),
                Text("$_seatsAvailable Seats", style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : kContentColor)),
                _buildSeatControl(Icons.add_rounded, () { if(_seatsAvailable < 4) setState(() => _seatsAvailable++); }, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalStep(bool isDark) {
    String formattedDate = DateUtils.isSameDay(_selectedDate, DateTime.now()) ? "Today" : DateFormat('EEE, MMM dd').format(_selectedDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderLabel("Schedule", "Finalize your trip timing"),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildInteractiveTile(Icons.calendar_month_rounded, "Date", formattedDate, _pickDate, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildInteractiveTile(Icons.access_time_filled_rounded, "Time", _selectedTime.format(context), _pickTime, isDark)),
            ],
          ),
          const SizedBox(height: 32),
          Text("Gender Policy", style: _sectionStyle(isDark)),
          const SizedBox(height: 12),
          Row(
            children: _genderOptions.map((g) {
              bool isSelected = _selectedGender == g;
              final IconData gIcon = g == 'Women' ? Icons.face_3_rounded : (g == 'Men' ? Icons.face_6_rounded : Icons.face_rounded);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? kPrimaryBlue.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.03) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? kPrimaryBlue : (isDark ? Colors.white10 : kBorderColor)),
                    ),
                    child: Column(
                      children: [
                        Icon(gIcon, size: 20, color: isSelected ? kPrimaryBlue : kSecondaryText),
                        const SizedBox(height: 4),
                        Text(
                          g,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: isSelected ? kPrimaryBlue : kSecondaryText),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Text("Notes", style: _sectionStyle(isDark)),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : kContentColor, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: "Pickup point instructions, rules...",
              hintStyle: GoogleFonts.plusJakartaSans(color: kSecondaryText.withOpacity(0.4)),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? Colors.white10 : kBorderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? Colors.white10 : kBorderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: kPrimaryBlue, width: 2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderLabel(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w900, color: kPrimaryBlue, letterSpacing: -0.5)),
        Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 15, color: kSecondaryText, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildFormCard(bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : kBorderColor),
        boxShadow: isDark ? null : [BoxShadow(color: kContentColor.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }

  Widget _buildBottomActions(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : kBorderColor)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? Colors.white10 : kBorderColor),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _previousStep,
                    child: Center(
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: isDark ? Colors.white : kContentColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 58),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: Text(
                _currentStep == 2 ? "Publish Ride" : "Next Step",
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTile(IconData icon, String label, String value, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : kBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: kPrimaryBlue, size: 20),
            const SizedBox(height: 12),
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: kSecondaryText)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? Colors.white : kContentColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatControl(IconData icon, VoidCallback onTap, bool isDark) {
    return Material(
      color: isDark ? Colors.white.withOpacity(0.05) : kPrimaryBlue.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: kPrimaryBlue, size: 24),
        ),
      ),
    );
  }

  TextStyle _sectionStyle(bool isDark) => GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white70 : kContentColor, letterSpacing: 0.3);

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _selectedTime);
    if (t != null) setState(() => _selectedTime = t);
  }
}
