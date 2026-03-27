import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  bool _creating = false;

  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kText = Color(0xFF0F172A);
  static const Color kSecondary = Color(0xFF64748B);
  static const Color kRed = Color(0xFFFD6B6B);
  static const Color kAmber = Color(0xFFF59E0B);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _creating = true);
    final result = await FirestoreService.createGroup(name);
    setState(() => _creating = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: result.success ? const Color(0xFF10B981) : kRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      if (result.success) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Create Group", style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800, fontSize: 18, color: kText,
        )),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Warning banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kAmber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kAmber.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: kAmber, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Auto-Dissolve Rule", style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w800, color: kAmber,
                        )),
                        const SizedBox(height: 4),
                        Text(
                          "If the ride is not ended manually, the group will automatically dissolve after 24 hours.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w500, color: kText.withOpacity(0.7),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Group info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("DESTINATION", style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w800, color: kSecondary, letterSpacing: 1.2,
                  )),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "e.g. North South University",
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: kSecondary.withOpacity(0.5),
                      ),
                      prefixIcon: Icon(Icons.location_on_rounded, color: kRed, size: 22),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kPrimary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded, size: 16, color: kSecondary.withOpacity(0.5)),
                      const SizedBox(width: 8),
                      Text("Maximum 3 members (including you)", style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: kSecondary.withOpacity(0.7),
                      )),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Create button
            SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : _create,
                icon: _creating
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.group_add_rounded, color: Colors.white),
                label: Text(
                  _creating ? "Creating..." : "Create Group",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRed,
                  disabledBackgroundColor: kRed.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
