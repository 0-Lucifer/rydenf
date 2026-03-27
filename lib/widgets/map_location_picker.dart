import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;
import '../services/location_service.dart';
import '../services/places_service.dart';

/// Full-screen Uber-style map location picker.
///
/// Shows a Google Map with a fixed center pin. User drags the map to move
/// the pin, or searches by name. Returns (name, lat, lng) on confirm.
class MapLocationPicker extends StatefulWidget {
  final String title;
  final LatLng? initialPosition;
  final Color accentColor;

  const MapLocationPicker({
    super.key,
    this.title = 'Pick Location',
    this.initialPosition,
    this.accentColor = const Color(0xFF4F46E5),
  });

  /// Opens the picker and returns `(name, lat, lng)` or null if cancelled.
  static Future<({String name, double lat, double lng})?> pick(
    BuildContext context, {
    String title = 'Pick Location',
    LatLng? initialPosition,
    Color accentColor = const Color(0xFF4F46E5),
  }) {
    return Navigator.of(context).push<({String name, double lat, double lng})>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MapLocationPicker(
          title: title,
          initialPosition: initialPosition,
          accentColor: accentColor,
        ),
      ),
    );
  }

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  GoogleMapController? _mapController;

  // Dhaka center as fallback
  static const LatLng _defaultCenter = LatLng(23.8103, 90.4125);

  late LatLng _currentCenter;
  String _resolvedAddress = 'Move the map to pick a location';
  bool _isResolvingAddress = false;
  bool _isLoadingGps = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  List<PlacePrediction> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialPosition ?? _defaultCenter;
    // Try GPS on launch if no initial position
    if (widget.initialPosition == null) {
      _goToMyLocation(animate: false);
    } else {
      _reverseGeocode(_currentCenter);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Reverse geocode the center pin position ────────────
  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _isResolvingAddress = true);
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.name != null && p.name!.isNotEmpty && p.name != p.postalCode)
            p.name!,
          if (p.subLocality != null && p.subLocality!.isNotEmpty)
            p.subLocality!,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
          if (p.administrativeArea != null &&
              p.administrativeArea!.isNotEmpty)
            p.administrativeArea!,
        ];
        setState(() {
          _resolvedAddress =
              parts.isNotEmpty ? parts.join(', ') : 'Unknown location';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _resolvedAddress = 'Unable to determine address');
      }
    } finally {
      if (mounted) setState(() => _isResolvingAddress = false);
    }
  }

  // ── Go to user's GPS location ──────────────────────────
  Future<void> _goToMyLocation({bool animate = true}) async {
    setState(() => _isLoadingGps = true);
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentCenter = target;
        _isLoadingGps = false;
      });
      if (_mapController != null) {
        if (animate) {
          _mapController!
              .animateCamera(CameraUpdate.newLatLngZoom(target, 16));
        } else {
          _mapController!
              .moveCamera(CameraUpdate.newLatLngZoom(target, 16));
        }
      }
      _reverseGeocode(target);
    } else {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  // ── Search places ──────────────────────────────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isSearching = true);
      final results = await PlacesService.getSuggestions(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _showSearchResults = results.isNotEmpty;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _selectSearchResult(PlacePrediction prediction) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _showSearchResults = false;
      _searchController.text = prediction.description;
    });

    final coords = await PlacesService.getPlaceDetails(prediction.placeId);
    if (coords != null && mounted) {
      final target = LatLng(coords.lat, coords.lng);
      setState(() {
        _currentCenter = target;
        _resolvedAddress = prediction.description;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
    }
  }

  // ── Confirm and return ─────────────────────────────────
  void _confirm() {
    Navigator.of(context).pop((
      name: _resolvedAddress,
      lat: _currentCenter.latitude,
      lng: _currentCenter.longitude,
    ));
  }

  // ── Camera idle → resolve address ──────────────────────
  void _onCameraIdle() {
    _reverseGeocode(_currentCenter);
  }

  void _onCameraMove(CameraPosition pos) {
    _currentCenter = pos.target;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Google Map ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // ── Center pin (fixed) ──
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withAlpha(80),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.location_on,
                        color: Colors.white, size: 24),
                  ),
                  // Pin shadow dot
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(60),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Top bar: back + search ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Back + Title row
                  Row(
                    children: [
                      _backButton(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _searchBar(),
                      ),
                    ],
                  ),
                  // Search results dropdown
                  if (_showSearchResults) _searchResultsList(),
                ],
              ),
            ),
          ),

          // ── My location FAB ──
          Positioned(
            right: 16,
            bottom: 240,
            child: FloatingActionButton.small(
              heroTag: 'myLocationFab',
              onPressed: _isLoadingGps ? null : () => _goToMyLocation(),
              backgroundColor: Colors.white,
              elevation: 4,
              child: _isLoadingGps
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.accentColor,
                      ),
                    )
                  : Icon(Icons.my_location_rounded,
                      color: widget.accentColor, size: 22),
            ),
          ),

          // ── Bottom panel: address + confirm ──
          Align(
            alignment: Alignment.bottomCenter,
            child: _bottomPanel(),
          ),
        ],
      ),
    );
  }

  Widget _backButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: Color(0xFF0F172A)),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        onTap: () {
          if (_searchResults.isNotEmpty) {
            setState(() => _showSearchResults = true);
          }
        },
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Search a place...',
          hintStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF94A3B8),
            fontSize: 14,
          ),
          prefixIcon:
              const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                )
              : (_searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _showSearchResults = false;
                        });
                      },
                    )
                  : null),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _searchResultsList() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: _searchResults.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (context, index) {
            final prediction = _searchResults[index];
            return ListTile(
              dense: true,
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.location_on_rounded,
                    size: 18, color: widget.accentColor),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              onTap: () => _selectSearchResult(prediction),
            );
          },
        ),
      ),
    );
  }

  Widget _bottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Address row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.location_on_rounded,
                    color: widget.accentColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Location',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    _isResolvingAddress
                        ? Row(
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: widget.accentColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Finding address...',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _resolvedAddress,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isResolvingAddress ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                disabledBackgroundColor: widget.accentColor.withAlpha(120),
              ),
              child: Text(
                'Confirm Location',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
