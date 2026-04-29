import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Reverse geocode using the Google Maps JS SDK Geocoder.
/// This is already loaded on the page via index.html and never has auth issues.
Future<String?> geocodeWithMapsJS(double lat, double lng) async {
  final completer = Completer<String?>();

  try {
    final mapsNs = js.context['google']?['maps'];
    if (mapsNs == null) {
      completer.complete(null);
      return completer.future;
    }

    final geocoder = js.JsObject(mapsNs['Geocoder'] as js.JsFunction);
    final latLng = js.JsObject(
      mapsNs['LatLng'] as js.JsFunction,
      [lat, lng],
    );

    geocoder.callMethod('geocode', [
      js.JsObject.jsify({'location': latLng}),
      js.allowInterop((dynamic results, String status) {
        if (status == 'OK' && results != null) {
          try {
            final arr = results as js.JsArray;
            if (arr.length > 0) {
              final address =
                  (arr[0] as js.JsObject)['formatted_address'] as String?;
              completer.complete(address);
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
