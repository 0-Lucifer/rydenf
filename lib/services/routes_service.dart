import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Google Routes API service for distance, duration, and polyline.
class RoutesService {
  static String get _apiKey => AppConfig.googleMapsApiKey;

  /// Compute route between two points. Returns distance (km), duration (min), and encoded polyline.
  /// Uses the Google Routes API (computeRoutes) via dart:io HttpClient.
  static Future<RouteInfo?> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    if (_apiKey.isEmpty) return null;

    try {
      final url = Uri.parse(AppConfig.routesApiUrl);

      final body = jsonEncode({
        'origin': {
          'location': {
            'latLng': {'latitude': originLat, 'longitude': originLng},
          },
        },
        'destination': {
          'location': {
            'latLng': {'latitude': destLat, 'longitude': destLng},
          },
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
        'computeAlternativeRoutes': false,
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          final distanceMeters = route['distanceMeters'] as int? ?? 0;
          final durationStr = route['duration'] as String? ?? '0s';
          final polyline = route['polyline']?['encodedPolyline'] as String? ?? '';

          // Parse "123s" duration string to minutes
          final durationSeconds = int.tryParse(durationStr.replaceAll('s', '')) ?? 0;

          return RouteInfo(
            distanceKm: distanceMeters / 1000.0,
            durationMinutes: (durationSeconds / 60.0).ceil(),
            encodedPolyline: polyline,
          );
        }
      } else {
        debugPrint('[RoutesService] API error ${response.statusCode}: ${response.body}');
      }
      return null;
    } catch (e) {
      debugPrint('[RoutesService] getRoute error: $e');
      return null;
    }
  }
}

/// Route information returned from Google Routes API.
class RouteInfo {
  final double distanceKm;
  final int durationMinutes;
  final String encodedPolyline;

  const RouteInfo({
    required this.distanceKm,
    required this.durationMinutes,
    required this.encodedPolyline,
  });

  /// Format distance as human readable string.
  String get distanceText {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Format duration as human readable string.
  String get durationText {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    }
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}
