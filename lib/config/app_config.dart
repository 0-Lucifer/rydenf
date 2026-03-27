import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Single source of truth for all API keys, base URLs, and app constants.
/// Every service reads from here — never hardcode keys or URLs elsewhere.
class AppConfig {
  AppConfig._();

  // ── API Keys ──────────────────────────────────────────
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // ── Google API Base URLs ──────────────────────────────
  static const String placesAutocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String placeDetailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';
  static const String routesApiUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  // ── Store URLs ────────────────────────────────────────
  // TODO: Replace with actual store listing URLs before production release
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.ryden.app';
  static const String appStoreUrl =
      'https://apps.apple.com/app/ryden/id000000000';
}
