import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/routes_service.dart';

/// A static Google Map preview showing origin + destination markers.
/// Optionally shows route info (distance + ETA).
class RideMapPreview extends StatefulWidget {
  final double? originLat, originLng, destLat, destLng;
  final double height;
  final bool showRouteInfo;
  final void Function(RouteInfo routeInfo)? onRouteCalculated;

  const RideMapPreview({
    super.key,
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    this.height = 200,
    this.showRouteInfo = true,
    this.onRouteCalculated,
  });

  @override
  State<RideMapPreview> createState() => _RideMapPreviewState();
}

class _RideMapPreviewState extends State<RideMapPreview> {
  GoogleMapController? _mapController;
  RouteInfo? _routeInfo;
  bool _isLoadingRoute = false;
  Set<Polyline> _polylines = {};

  bool get _hasCoordinates =>
      widget.originLat != null &&
      widget.originLng != null &&
      widget.destLat != null &&
      widget.destLng != null;

  LatLng get _origin => LatLng(widget.originLat!, widget.originLng!);
  LatLng get _dest => LatLng(widget.destLat!, widget.destLng!);

  @override
  void didUpdateWidget(RideMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.originLat != widget.originLat ||
        oldWidget.originLng != widget.originLng ||
        oldWidget.destLat != widget.destLat ||
        oldWidget.destLng != widget.destLng) {
      if (_hasCoordinates) {
        _fitBounds();
        _fetchRoute();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (_hasCoordinates) {
      _fetchRoute();
    }
  }

  Future<void> _fetchRoute() async {
    if (!_hasCoordinates) return;

    setState(() => _isLoadingRoute = true);

    final routeInfo = await RoutesService.getRoute(
      originLat: widget.originLat!,
      originLng: widget.originLng!,
      destLat: widget.destLat!,
      destLng: widget.destLng!,
    );

    if (mounted) {
      setState(() {
        _routeInfo = routeInfo;
        _isLoadingRoute = false;
        if (routeInfo != null && routeInfo.encodedPolyline.isNotEmpty) {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: _decodePolyline(routeInfo.encodedPolyline),
              color: const Color(0xFF4F46E5),
              width: 4,
            ),
          };
        }
      });
      if (routeInfo != null) {
        widget.onRouteCalculated?.call(routeInfo);
      }
    }
  }

  void _fitBounds() {
    if (_mapController == null || !_hasCoordinates) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        min(widget.originLat!, widget.destLat!),
        min(widget.originLng!, widget.destLng!),
      ),
      northeast: LatLng(
        max(widget.originLat!, widget.destLat!),
        max(widget.originLng!, widget.destLng!),
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  /// Decode Google encoded polyline string into list of LatLng.
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0, result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCoordinates) return const SizedBox.shrink();

    return Column(
      children: [
        // Map
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (widget.originLat! + widget.destLat!) / 2,
                  (widget.originLng! + widget.destLng!) / 2,
                ),
                zoom: 12,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('origin'),
                  position: _origin,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                ),
                Marker(
                  markerId: const MarkerId('destination'),
                  position: _dest,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
              },
              polylines: _polylines,
              onMapCreated: (controller) {
                _mapController = controller;
                // Fit bounds after a short delay to ensure map is ready
                Future.delayed(const Duration(milliseconds: 300), _fitBounds);
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              zoomGesturesEnabled: false,
              liteModeEnabled: false,
            ),
          ),
        ),

        // Route info bar
        if (widget.showRouteInfo) ...[
          const SizedBox(height: 12),
          _buildRouteInfoBar(),
        ],
      ],
    );
  }

  Widget _buildRouteInfoBar() {
    if (_isLoadingRoute) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 10),
            Text(
              'Calculating route...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    if (_routeInfo == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.route_rounded, size: 18, color: Color(0xFF4F46E5)),
          const SizedBox(width: 10),
          Text(
            _routeInfo!.distanceText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF94A3B8),
              shape: BoxShape.circle,
            ),
          ),
          const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF4F46E5)),
          const SizedBox(width: 6),
          Text(
            _routeInfo!.durationText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
