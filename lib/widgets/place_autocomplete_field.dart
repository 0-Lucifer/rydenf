import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/places_service.dart';
import 'map_location_picker.dart';
import '../services/location_service.dart';

/// A text field with Google Places autocomplete dropdown.
/// Returns selected place name + coordinates via [onPlaceSelected].
class PlaceAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Color markerColor;
  final IconData? prefixIcon;
  final void Function(String name, double lat, double lng)? onPlaceSelected;

  const PlaceAutocompleteField({
    super.key,
    required this.controller,
    this.hintText = 'Search location...',
    this.markerColor = const Color(0xFF4F46E5),
    this.prefixIcon,
    this.onPlaceSelected,
  });

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<PlacePrediction> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;
  bool _ignoreNextChange = false;
  bool _placeSelected = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (_ignoreNextChange) {
      _ignoreNextChange = false;
      return;
    }

    // User is manually typing, so clear the selection flag
    _placeSelected = false;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchPlaces(widget.controller.text);
    });
  }

  Future<void> _searchPlaces(String input) async {
    // Don't search if a place is already selected
    if (_placeSelected) return;

    if (input.trim().length < 2) {
      _removeOverlay();
      return;
    }

    setState(() => _isLoading = true);
    final results = await PlacesService.getSuggestions(input);

    if (mounted) {
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
      if (_suggestions.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Full-screen tap barrier — dismisses overlay when tapping outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _removeOverlay();
                FocusScope.of(context).unfocus();
              },
              behavior: HitTestBehavior.translucent,
            ),
          ),
          // The actual suggestion dropdown
          Positioned(
            width: _getFieldWidth(),
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 52),
              child: Material(
                elevation: 12,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        // "Use my location" option
                        _buildMyLocationTile(),
                        if (_suggestions.isNotEmpty)
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        ..._suggestions.map(_buildSuggestionTile),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildMyLocationTile() {
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF10B981)),
      ),
      title: Text(
        'Use my current location',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: const Color(0xFF10B981),
        ),
      ),
      onTap: () async {
        _debounce?.cancel();
        _removeOverlay();
        final position = await LocationService.getCurrentPosition();
        if (position != null) {
          _ignoreNextChange = true;
          _placeSelected = true;
          _suggestions = [];
          widget.controller.text = 'My Location';
          widget.onPlaceSelected?.call('My Location', position.latitude, position.longitude);
        }
      },
    );
  }

  Widget _buildSuggestionTile(PlacePrediction prediction) {
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: widget.markerColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.location_on_rounded, size: 18, color: widget.markerColor),
      ),
      title: Text(
        prediction.mainText,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: const Color(0xFF0F172A),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: prediction.secondaryText.isNotEmpty
          ? Text(
              prediction.secondaryText,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: () => _selectPrediction(prediction),
    );
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    _debounce?.cancel();
    _removeOverlay();

    _ignoreNextChange = true;
    _placeSelected = true;
    _suggestions = [];
    widget.controller.text = prediction.description;

    // Unfocus the text field so the keyboard goes away
    FocusScope.of(context).unfocus();

    // Get lat/lng from place ID
    if (prediction.placeId.isNotEmpty) {
      final coords = await PlacesService.getPlaceDetails(prediction.placeId);
      if (coords != null) {
        widget.onPlaceSelected?.call(prediction.description, coords.lat, coords.lng);
      }
    }
  }

  Future<void> _openMapPicker() async {
    _debounce?.cancel();
    _removeOverlay();
    _suggestions = [];
    final result = await MapLocationPicker.pick(
      context,
      title: widget.hintText,
      accentColor: widget.markerColor,
    );
    if (result != null && mounted) {
      _ignoreNextChange = true;
      _placeSelected = true;
      widget.controller.text = result.name;
      widget.onPlaceSelected?.call(result.name, result.lat, result.lng);
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  double _getFieldWidth() {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 300;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                  ),
                )
              else if (widget.controller.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear_rounded, size: 18, color: Colors.grey.shade400),
                  onPressed: () {
                    widget.controller.clear();
                    _removeOverlay();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              // Map picker button
              IconButton(
                icon: Icon(Icons.map_rounded, size: 20, color: widget.markerColor.withAlpha(180)),
                onPressed: _openMapPicker,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                tooltip: 'Pick on map',
              ),
            ],
          ),
        ),
        onTap: () {
          // Only re-show suggestions if user hasn't already selected a place
          if (!_placeSelected && widget.controller.text.length >= 2) {
            _searchPlaces(widget.controller.text);
          }
        },
      ),
    );
  }
}
