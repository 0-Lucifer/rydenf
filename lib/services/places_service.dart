import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'places_stub.dart' if (dart.library.js) 'places_web.dart';

/// Google Places Autocomplete service using direct HTTP calls.
/// No external package needed — avoids dependency conflicts.
class PlacesService {
  static String get _apiKey => AppConfig.googleMapsApiKey;

  /// Search for place suggestions based on user input.
  /// Returns a list of [PlacePrediction] objects.
  static Future<List<PlacePrediction>> getSuggestions(String input) async {
    if (input.trim().isEmpty) return [];

    // On web, use Maps JS AutocompleteService (already loaded, no key issues).
    if (kIsWeb) {
      final raw = await webGetSuggestions(input);
      return raw
          .map((p) => PlacePrediction(
                placeId: p['place_id'] as String? ?? '',
                description: p['description'] as String? ?? '',
                mainText: p['main_text'] as String? ?? '',
                secondaryText: p['secondary_text'] as String? ?? '',
              ))
          .toList();
    }

    if (_apiKey.isEmpty) return [];

    try {
      final url = Uri.parse(
        '${AppConfig.placesAutocompleteUrl}'
        '?input=${Uri.encodeComponent(input)}'
        '&components=country:bd'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predictions = data['predictions'] as List? ?? [];
        return predictions.map((p) => PlacePrediction.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[PlacesService] autocomplete error: $e');
      return [];
    }
  }

  /// Get lat/lng details for a specific place by its placeId.
  static Future<({double lat, double lng})?> getPlaceDetails(
      String placeId) async {
    if (placeId.isEmpty) return null;

    // On web, use Maps JS Geocoder with placeId (already loaded, no key issues).
    if (kIsWeb) {
      final raw = await webGetPlaceDetails(placeId);
      if (raw == null) return null;
      return (lat: raw['lat']!, lng: raw['lng']!);
    }

    if (_apiKey.isEmpty) return null;

    try {
      final url = Uri.parse(
        '${AppConfig.placeDetailsUrl}'
        '?place_id=${Uri.encodeComponent(placeId)}'
        '&fields=geometry'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final location = data['result']?['geometry']?['location'];
        if (location != null) {
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          return (lat: lat, lng: lng);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[PlacesService] getPlaceDetails error: $e');
      return null;
    }
  }
}

/// A place prediction from Google Places Autocomplete.
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] ?? {};
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structured['main_text'] ?? json['description'] ?? '',
      secondaryText: structured['secondary_text'] ?? '',
    );
  }
}
