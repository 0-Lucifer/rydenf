import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Redesigned UI Constants ---
class RydenTokens {
  static const Color primary = Color(0xFF2E7CF6);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const double cardRadius = 24.0;
  static const double sheetRadius = 32.0;
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 24);
}

// Keep original theme constants for compatibility if needed elsewhere, 
// but redesign uses RydenTokens and Material 3 Theme.
const Color kPrimaryBlue = Color(0xFF2E7CF6);
const Color kContentColor = Color(0xFF0F172A);
const Color kSecondaryText = Color(0xFF64748B);
const Color kBgColor = Color(0xFFF8FAFC);
const Color kSuccessGreen = Color(0xFF10B981);
const Color kErrorRed = Color(0xFFEF4444);
const Color kBorderColor = Color(0xFFE2E8F0);

/// Redesigned Entry Point
void showGroupRideDetails(BuildContext context, Map<String, dynamic> ride) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (context) => GroupRideDetailsSheet(ride: ride),
  );
}

class GroupRideDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> ride;
  const GroupRideDetailsSheet({super.key, required this.ride});

  @override
  State<GroupRideDetailsSheet> createState() => _GroupRideDetailsSheetState();
}

class _GroupRideDetailsSheetState extends State<GroupRideDetailsSheet> {
  bool _isRequesting = false;

  void _handleJoinRequest() async {
    if (widget.ride['isFull'] == true || widget.ride['seatsLeft'] == 0) return;
    setState(() => _isRequesting = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) {
      setState(() => _isRequesting = false);
      Navigator.pop(context);
      _showPremiumSnackBar(context, "Request sent to ${widget.ride['host']}!", RydenTokens.success);
    }
  }

  void _handleChat() {
    Navigator.pop(context);
    _showPremiumSnackBar(context, "Chatting with host ${widget.ride['host']}...", RydenTokens.primary);
  }

  void _showPremiumSnackBar(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFull = widget.ride['isFull'] ?? (widget.ride['seatsLeft'] == 0);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600), // Responsive Constraint for Tablet/Desktop
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(RydenTokens.sheetRadius)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                )
              ],
            ),
            child: Column(
              children: [
                _buildDragHandle(isDark),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: RydenTokens.screenPadding,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildHeader(isFull, isDark),
                      const SizedBox(height: 24),
                      _buildStatsGrid(isDark),
                      const SizedBox(height: 32),
                      _buildRouteSection(isDark),
                      const SizedBox(height: 32),
                      _buildHostSection(isDark),
                      const SizedBox(height: 32),
                      _buildRefinedSection("Ride Notes", _buildNotes(isDark), isDark),
                      const SizedBox(height: 24),
                      _buildRefinedSection("Rules & Safety", _buildGuidelines(isDark), isDark),
                      const SizedBox(height: 40),
                      _buildFooterActions(isDark),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                _buildStickyFooter(isFull, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: 48,
      height: 6,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildHeader(bool isFull, bool isDark) {
    final statusColor = isFull ? RydenTokens.danger : RydenTokens.success;
    final seatsLeft = widget.ride['seatsLeft'] ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // --- Redesigned Top-Notch Status Badge ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: statusColor.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicator dot with glow
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isFull 
                  ? "RIDE FULL" 
                  : "$seatsLeft ${seatsLeft == 1 ? 'SEAT' : 'SEATS'} REMAINING",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: statusColor,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(RydenTokens.cardRadius),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: _StatItem(Icons.schedule_rounded, "Time", widget.ride['time'], isDark)),
            _buildVerticalDivider(isDark),
            Expanded(child: _StatItem(Icons.commute_rounded, "Mode", widget.ride['transport'], isDark)),
            _buildVerticalDivider(isDark),
            Expanded(child: _StatItem(Icons.face_retouching_natural_rounded, "Gender", widget.ride['gender'], isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) => VerticalDivider(color: isDark ? Colors.white12 : Colors.grey[300], width: 1);

  Widget _buildRouteSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle("Route Details", isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RydenTokens.cardRadius),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RouteNode(Icons.radio_button_checked_rounded, RydenTokens.primary, "Pickup Point", widget.ride['from'], isDark),
              Container(
                margin: const EdgeInsets.only(left: 11),
                height: 30,
                width: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [RydenTokens.primary, RydenTokens.danger.withOpacity(0.5)],
                  ),
                ),
              ),
              _RouteNode(Icons.location_on_rounded, RydenTokens.danger, "Drop-off Point", widget.ride['to'], isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHostSection(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle("Host", isDark),
            TextButton(
              onPressed: () {},
              child: Text("View Profile", style: GoogleFonts.plusJakartaSans(color: RydenTokens.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RydenTokens.cardRadius),
            color: RydenTokens.primary.withOpacity(0.05),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: RydenTokens.primary,
                child: Text(widget.ride['host'][0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.ride['host'], style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                        Text(" ${widget.ride['rating']} • Trusted Host", style: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.ride['isVerified'] ?? false)
                const Icon(Icons.verified_rounded, color: RydenTokens.primary, size: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRefinedSection(String title, Widget content, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title, isDark),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildNotes(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Text(
        widget.ride['notes'] ?? "Host has not added extra notes for this trip.",
        style: GoogleFonts.plusJakartaSans(height: 1.6, color: isDark ? Colors.white70 : Colors.black87),
      ),
    );
  }

  Widget _buildGuidelines(bool isDark) {
    final List<Map<String, dynamic>> rules = [
      {"icon": Icons.timer_outlined, "label": "Punctuality is required"},
      {"icon": Icons.groups_outlined, "label": "Respect co-passengers"},
      {"icon": Icons.smoke_free_rounded, "label": "No smoking inside"},
    ];
    return Column(
      children: rules.map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(r['icon'], size: 20, color: RydenTokens.primary),
            const SizedBox(width: 12),
            Text(r['label'], style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildFooterActions(bool isDark) {
    return Center(
      child: TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.flag_outlined, size: 16),
        label: const Text("Report this ride"),
        style: TextButton.styleFrom(foregroundColor: Colors.grey, textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildStickyFooter(bool isFull, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: _CustomButton(
              onTap: _handleChat,
              icon: Icons.chat_bubble_outline_rounded,
              label: "Chat with Host",
              isPrimary: false,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: _CustomButton(
              onTap: isFull ? null : _handleJoinRequest,
              label: isFull ? "Ride Full" : "Request to Join",
              isPrimary: true,
              isLoading: _isRequesting,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Internal Reusable Components ---

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionTitle(this.title, this.isDark);
  @override
  Widget build(BuildContext context) => Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black, letterSpacing: 0.3));
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool isDark;
  
  const _StatItem(this.icon, this.label, this.value, this.isDark);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: RydenTokens.primary, size: 22),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.bold)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
        ),
      ],
    );
  }
}

class _RouteNode extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, val;
  final bool isDark;
  const _RouteNode(this.icon, this.color, this.title, this.val, this.isDark);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.bold)),
              Text(val, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final IconData? icon;
  final bool isPrimary, isLoading, isDark;
  const _CustomButton({this.onTap, required this.label, this.icon, required this.isPrimary, this.isLoading = false, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary ? RydenTokens.primary : (isDark ? Colors.white12 : const Color(0xFFF1F5F9));
    final fgColor = isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black);

    return Material(
      color: onTap == null ? Colors.grey[300] : bgColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, color: fgColor, size: 20), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(
                        label, 
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: fgColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
