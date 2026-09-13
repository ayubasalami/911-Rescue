import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/geo_point.dart';

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService(ref.watch(appConfigProvider).mapboxAccessToken);
});

/// Thin client over Mapbox's Geocoding REST API — same pattern as
/// [AccessAnalysisService] for the Isochrone/Matrix/Directions APIs, since
/// reverse geocoding isn't covered by mapbox_maps_flutter's native bindings
/// either.
class GeocodingService {
  GeocodingService(this._accessToken, {http.Client? client})
    : _client = client ?? http.Client();

  final String _accessToken;
  final http.Client _client;

  static const _base = 'https://api.mapbox.com';

  /// A human-readable street address for [point], for the "Address sent"
  /// line on a Ping for Help card — matches the web platform's reverse
  /// geocoding of the pinged location.
  Future<String> reverseGeocode(GeoPoint point) async {
    final uri = Uri.parse(
      '$_base/geocoding/v5/mapbox.places/${point.longitude},${point.latitude}.json',
    ).replace(queryParameters: {'access_token': _accessToken, 'limit': '1'});

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Mapbox geocoding request failed (${response.statusCode}): ${response.body}',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = body['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      throw Exception('No address found for this location');
    }
    return (features.first as Map<String, dynamic>)['place_name'] as String;
  }
}
