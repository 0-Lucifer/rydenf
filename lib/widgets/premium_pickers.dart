import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium date & time pickers that open as gorgeous bottom-sheets.
class PremiumPickers {
  // ─── Brand palette ───
  static const _accent = Color(0xFF4F46E5);
  static const _accentLight = Color(0xFFEEF2FF);
  static const _surface = Color(0xFFF8FAFC);
  static const _dark = Color(0xFF0F172A);
  static const _subtle = Color(0xFF94A3B8);

  // ═══════════════════════════════════════════════════════
  //  DATE PICKER (bottom-sheet calendar)
  // ═══════════════════════════════════════════════════════

  /// Shows a beautifully themed date picker.
  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? now,
      lastDate: lastDate ?? now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _accent,
              onPrimary: Colors.white,
              onSurface: _dark,
              surface: Colors.white,
              surfaceContainerHighest: _surface,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              headerBackgroundColor: _accent,
              headerForegroundColor: Colors.white,
              headerHeadlineStyle: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              headerHelpStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
              dayStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              weekdayStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _subtle,
              ),
              yearStyle: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              todayBorder: const BorderSide(color: _accent, width: 2),
              todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return _accent;
              }),
              todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _accent;
                return Colors.transparent;
              }),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                if (states.contains(WidgetState.disabled)) return _subtle.withValues(alpha: 0.4);
                return _dark;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _accent;
                return Colors.transparent;
              }),
              dayOverlayColor: WidgetStateProperty.all(_accentLight),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shadowColor: Colors.transparent,
              rangePickerSurfaceTintColor: Colors.transparent,
              confirmButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(_accent),
                textStyle: WidgetStateProperty.all(
                  GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              cancelButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(_subtle),
                textStyle: WidgetStateProperty.all(
                  GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                textStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  //  TIME PICKER (premium styled)
  // ═══════════════════════════════════════════════════════

  /// Shows a beautifully themed time picker.
  static Future<TimeOfDay?> pickTime(
    BuildContext context, {
    required TimeOfDay initialTime,
  }) async {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _accent,
              onPrimary: Colors.white,
              onSurface: _dark,
              surface: Colors.white,
              tertiary: _accent,
              onTertiary: Colors.white,
              surfaceContainerHighest: _accentLight,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              hourMinuteColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _accentLight;
                return _surface;
              }),
              hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _accent;
                return _dark;
              }),
              hourMinuteTextStyle: GoogleFonts.plusJakartaSans(
                fontSize: 48,
                fontWeight: FontWeight.w800,
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              dayPeriodColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _accent;
                return _surface;
              }),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return _dark;
              }),
              dayPeriodTextStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              dayPeriodBorderSide: const BorderSide(color: _accent, width: 1.5),
              dialHandColor: _accent,
              dialBackgroundColor: _accentLight,
              dialTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return _dark;
              }),
              dialTextStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              entryModeIconColor: _accent,
              helpTextStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _subtle,
                letterSpacing: 1.2,
              ),
              elevation: 0,
              padding: const EdgeInsets.all(24),
              confirmButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(_accent),
                textStyle: WidgetStateProperty.all(
                  GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              cancelButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(_subtle),
                textStyle: WidgetStateProperty.all(
                  GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                textStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
      },
    );
  }
}
