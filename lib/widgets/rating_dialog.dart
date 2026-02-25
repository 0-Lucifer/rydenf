import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

/// Shows a premium rating bottom sheet for a single user.
/// Returns true if rating was submitted, false if skipped.
Future<bool> showRatingDialog(
  BuildContext context, {
  required UserProfile targetUser,
  required String rideId,
  required String rideType,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _RatingSheet(
      targetUser: targetUser,
      rideId: rideId,
      rideType: rideType,
    ),
  );
  return result ?? false;
}

/// Shows rating dialogs sequentially for multiple users.
/// Used when driver rates all passengers after ride completion.
Future<void> showSequentialRatingDialogs(
  BuildContext context, {
  required List<UserProfile> users,
  required String rideId,
  required String rideType,
}) async {
  for (final user in users) {
    if (!context.mounted) break;
    await showRatingDialog(
      context,
      targetUser: user,
      rideId: rideId,
      rideType: rideType,
    );
  }
}

class _RatingSheet extends StatefulWidget {
  final UserProfile targetUser;
  final String rideId;
  final String rideType;

  const _RatingSheet({
    required this.targetUser,
    required this.rideId,
    required this.rideType,
  });

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> with SingleTickerProviderStateMixin {
  int _selectedRating = 0;
  bool _isSubmitting = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  static const _kPrimary = Color(0xFF2E7CF6);
  static const _kGold = Color(0xFFF59E0B);
  static const _kDark = Color(0xFF0F172A);
  static const _kMuted = Color(0xFF64748B);
  static const _kSuccess = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String get _ratingLabel {
    switch (_selectedRating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Great';
      case 5: return 'Excellent';
      default: return 'Tap a star';
    }
  }

  Color get _ratingColor {
    switch (_selectedRating) {
      case 1: return const Color(0xFFEF4444);
      case 2: return const Color(0xFFF97316);
      case 3: return _kGold;
      case 4: return _kSuccess;
      case 5: return _kPrimary;
      default: return _kMuted;
    }
  }

  void _submit() async {
    if (_selectedRating == 0) return;
    setState(() => _isSubmitting = true);

    final result = await FirestoreService.submitRating(
      ratedUserId: widget.targetUser.uid,
      rating: _selectedRating,
      rideId: widget.rideId,
      rideType: widget.rideType,
    );

    if (mounted) {
      Navigator.pop(context, result.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.targetUser;
    final initials = user.displayName.isNotEmpty
        ? user.displayName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(color: _kDark.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              'Rate Your Experience',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20, fontWeight: FontWeight.w900, color: _kDark,
              ),
            ),
            const SizedBox(height: 24),

            // User avatar + info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kPrimary, Color(0xFF1D6AE5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName.isNotEmpty ? user.displayName : 'Unknown',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16, fontWeight: FontWeight.w800, color: _kDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w600, color: _kMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isSelected = starIndex <= _selectedRating;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = starIndex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: isSelected ? 48 : 40,
                      color: isSelected ? _kGold : Colors.grey[300],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            // Rating label
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _ratingLabel,
                key: ValueKey(_selectedRating),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _ratingColor,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Buttons
            Row(
              children: [
                // Skip button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800, color: _kMuted, fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Submit button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_selectedRating == 0 || _isSubmitting) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        disabledBackgroundColor: Colors.grey[200],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22, width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(
                              'Submit',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800, fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
