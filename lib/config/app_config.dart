import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Keeping all settings in one place so I don't have to hunt for URLs and keys later.
class AppConfig {
  AppConfig._();

  // Google Maps API Key from .env
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Base URLs for Google APIs
  static const String placesAutocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String placeDetailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';
  static const String routesApiUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  // Store links for the force update screen. I need to change these once the app is published.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.ryden.app';
  static const String appStoreUrl =
      'https://apps.apple.com/app/ryden/id000000000';
}
