import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Autocomplete using google.maps.places.AutocompleteService.
/// Note: Deprecated March 2025 for new customers but not discontinued —
/// still fully functional and supported with bug fixes.
Future<List<Map<String, dynamic>>> webGetSuggestions(String input) async {
  final completer = Completer<List<Map<String, dynamic>>>();

  try {
    final mapsNs = js.context['google']?['maps'];
    if (mapsNs == null) {
      completer.complete([]);
      return completer.future;
    }

    final placesNs = mapsNs['places'] as js.JsObject?;
    if (placesNs == null) {
      completer.complete([]);
      return completer.future;
    }

    final service =
        js.JsObject(placesNs['AutocompleteService'] as js.JsFunction);

    service.callMethod('getPlacePredictions', [
      js.JsObject.jsify({
        'input': input,
        'componentRestrictions': {'country': 'bd'},
      }),
      js.allowInterop((dynamic predictions, String status) {
        if (status == 'OK' && predictions != null) {
          try {
            final arr = predictions as js.JsArray;
            final results = <Map<String, dynamic>>[];
            for (var i = 0; i < arr.length; i++) {
              final p = arr[i] as js.JsObject;
              final structured = p['structured_formatting'];
              results.add({
                'place_id': p['place_id'] ?? '',
                'description': p['description'] ?? '',
                'main_text': structured != null
                    ? (structured as js.JsObject)['main_text'] ?? ''
                    : p['description'] ?? '',
                'secondary_text': structured != null
                    ? (structured as js.JsObject)['secondary_text'] ?? ''
                    : '',
              });
            }
            completer.complete(results);
            return;
          } catch (_) {}
        }
        completer.complete([]);
      }),
    ]);
  } catch (e) {
    completer.complete([]);
  }

  return completer.future;
}

/// Get lat/lng for a place ID using the Maps JS Geocoder (stable, no deprecation).
Future<Map<String, double>?> webGetPlaceDetails(String placeId) async {
  final completer = Completer<Map<String, double>?>();

  try {
    final mapsNs = js.context['google']?['maps'];
    if (mapsNs == null) {
      completer.complete(null);
      return completer.future;
    }

    final geocoder = js.JsObject(mapsNs['Geocoder'] as js.JsFunction);
    geocoder.callMethod('geocode', [
      js.JsObject.jsify({'placeId': placeId}),
      js.allowInterop((dynamic results, String status) {
        if (status == 'OK' && results != null) {
          try {
            final arr = results as js.JsArray;
            if (arr.length > 0) {
              final result = arr[0] as js.JsObject;
              final geometry = result['geometry'] as js.JsObject;
              final location = geometry['location'] as js.JsObject;
              final lat =
                  (location.callMethod('lat', []) as num).toDouble();
              final lng =
                  (location.callMethod('lng', []) as num).toDouble();
              completer.complete({'lat': lat, 'lng': lng});
              return;
            }
          } catch (_) {}
        }
        completer.complete(null);
      }),
    ]);
  } catch (e) {
    completer.complete(null);
  }

  return completer.future;
}
