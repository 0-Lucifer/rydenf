import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/ride_model.dart';
import '../services/location_service.dart';
import '../services/firestore_service.dart';
import '../services/routes_service.dart';

/// Map widget that keeps track of active rides.
/// Shows the route between origin and destination, and if it's the driver looking at it,
/// it sends their GPS to Firestore every 30 seconds. Passengers just see the blue dot moving.
class LiveRideMap extends StatefulWidget {
  final Ride ride;
  final bool isDriver;
  final double height;

  const LiveRideMap({
    super.key,
    required this.ride,
    required this.isDriver,
    this.height = 300,
  });

  @override
  State<LiveRideMap> createState() => _LiveRideMapState();
}

class _LiveRideMapState extends State<LiveRideMap> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Timer? _locationTimer;
  LatLng? _driverPosition;
  RouteInfo? _routeInfo;
  bool _isLoadingRoute = false;

  bool get _hasCoordinates => widget.ride.hasCoordinates;

  LatLng get _origin =>
      LatLng(widget.ride.originLat!, widget.ride.originLng!);
  LatLng get _dest =>
      LatLng(widget.ride.destinationLat!, widget.ride.destinationLng!);

  @override
  void initState() {
    super.initState();

    // Initialize driver position from ride data if available
    if (widget.ride.driverLat != null && widget.ride.driverLng != null) {
      _driverPosition = LatLng(widget.ride.driverLat!, widget.ride.driverLng!);
    }

    if (_hasCoordinates) {
      _fetchRoute();
    }

    // If driver, start streaming GPS every 30 seconds
    if (widget.isDriver && widget.ride.status == 'in_progress') {
      _startDriverLocationStream();
    }
  }

  @override
  void didUpdateWidget(LiveRideMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update driver position when ride data changes (for passengers)
    if (!widget.isDriver &&
        widget.ride.driverLat != null &&
        widget.ride.driverLng != null) {
      final newPos = LatLng(widget.ride.driverLat!, widget.ride.driverLng!);
      if (_driverPosition != newPos) {
        setState(() => _driverPosition = newPos);
      }
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // Get the route from Google so we can draw the blue line on the map
  Future<void> _fetchRoute() async {
    if (!_hasCoordinates) return;
    setState(() => _isLoadingRoute = true);

    final routeInfo = await RoutesService.getRoute(
      originLat: widget.ride.originLat!,
      originLng: widget.ride.originLng!,
      destLat: widget.ride.destinationLat!,
      destLng: widget.ride.destinationLng!,
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
              width: 5,
            ),
          };
        }
      });
    }
  }

  // Start pinging Firestore with the driver's location every half minute
  void _startDriverLocationStream() {
    // Send immediately on start
    _updateDriverPosition();

    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateDriverPosition();
    });
  }

  Future<void> _updateDriverPosition() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _driverPosition = latLng);

      // Write to Firestore
      await FirestoreService.updateDriverLocation(
        widget.ride.id!,
        pos.latitude,
        pos.longitude,
      );
    }
  }

  // Zoom the map so all the markers fit on the screen nicely
  void _fitBounds() {
    if (_mapController == null || !_hasCoordinates) return;

    double minLat = min(_origin.latitude, _dest.latitude);
    double maxLat = max(_origin.latitude, _dest.latitude);
    double minLng = min(_origin.longitude, _dest.longitude);
    double maxLng = max(_origin.longitude, _dest.longitude);

    // Include driver position in bounds
    if (_driverPosition != null) {
      minLat = min(minLat, _driverPosition!.latitude);
      maxLat = max(maxLat, _driverPosition!.latitude);
      minLng = min(minLng, _driverPosition!.longitude);
      maxLng = max(maxLng, _driverPosition!.longitude);
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  // Create the pins for pickup, dropoff, and the driver's current spot
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_hasCoordinates) {
      markers.add(Marker(
        markerId: const MarkerId('origin'),
        position: _origin,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup', snippet: widget.ride.origin),
      ));

      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _dest,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
            title: 'Drop-off', snippet: widget.ride.destination),
      ));
    }

    // Driver live position marker
    if (_driverPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: widget.isDriver ? 'You' : 'Driver',
          snippet: 'Live location',
        ),
      ));
    }

    return markers;
  }

  // Turning Google's weird encoded polyline string into actual map coordinates
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
                color: Colors.black.withAlpha(15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _driverPosition ?? LatLng(
                      (_origin.latitude + _dest.latitude) / 2,
                      (_origin.longitude + _dest.longitude) / 2,
                    ),
                    zoom: 13,
                  ),
                  markers: _buildMarkers(),
                  polylines: _polylines,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    Future.delayed(
                        const Duration(milliseconds: 500), _fitBounds);
                  },
                  myLocationEnabled: widget.isDriver,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // Live indicator
                if (widget.ride.status == 'in_progress')
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF10B981),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Re-center button
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _fitBounds,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.center_focus_strong_rounded,
                          size: 20, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Route info bar
        if (_routeInfo != null) ...[
          const SizedBox(height: 12),
          _buildRouteInfoBar(),
        ] else if (_isLoadingRoute) ...[
          const SizedBox(height: 12),
          _buildLoadingBar(),
        ],
      ],
    );
  }

  Widget _buildRouteInfoBar() {
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
          const Icon(Icons.access_time_rounded,
              size: 18, color: Color(0xFF4F46E5)),
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

  Widget _buildLoadingBar() {
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
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF4F46E5)),
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
}
