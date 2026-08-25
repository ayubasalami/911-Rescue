import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/access_analysis.dart';
import '../models/geo_point.dart';

final accessAnalysisServiceProvider = Provider<AccessAnalysisService>((ref) {
  return AccessAnalysisService(ref.watch(appConfigProvider).mapboxAccessToken);
});

/// Thin client over Mapbox's Isochrone, Matrix, and Directions REST APIs.
/// These aren't covered by mapbox_maps_flutter's native SDK bindings, so we
/// call them directly with the same public access token used for the map.
class AccessAnalysisService {
  AccessAnalysisService(this._accessToken, {http.Client? client}) : _client = client ?? http.Client();

  final String _accessToken;
  final http.Client _client;

  static const _base = 'https://api.mapbox.com';

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Mapbox request failed (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Contour rings around [origin] for the given [mode], matching the web
  /// platform's 6 driving-time bands. Mapbox caps contours to ~4 per
  /// request, so this fetches them as two parallel requests.
  Future<List<IsochroneRing>> fetchIsochrone({
    required GeoPoint origin,
    required TransportMode mode,
  }) async {
    final results = await Future.wait([
      _fetchIsochroneContours(origin: origin, mode: mode, minutes: const [5, 10, 15, 20]),
      _fetchIsochroneContours(origin: origin, mode: mode, minutes: const [25, 30]),
    ]);
    return [...results[0], ...results[1]];
  }

  Future<List<IsochroneRing>> _fetchIsochroneContours({
    required GeoPoint origin,
    required TransportMode mode,
    required List<int> minutes,
  }) async {
    final uri = Uri.parse(
      '$_base/isochrone/v1/mapbox/${mode.mapboxProfile}/${origin.longitude},${origin.latitude}',
    ).replace(queryParameters: {
      'contours_minutes': minutes.join(','),
      'polygons': 'true',
      'access_token': _accessToken,
    });

    final json = await _getJson(uri);
    final features = json['features'] as List<dynamic>? ?? const [];
    return [
      for (final feature in features)
        _isochroneRingFromFeature(feature as Map<String, dynamic>),
    ];
  }

  IsochroneRing _isochroneRingFromFeature(Map<String, dynamic> feature) {
    final minutes = (feature['properties'] as Map<String, dynamic>)['contour'] as int;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final rings = geometry['coordinates'] as List<dynamic>;
    final outerRing = rings.first as List<dynamic>;
    return IsochroneRing(
      minutes: minutes,
      points: [
        for (final coordinate in outerRing)
          GeoPoint(
            longitude: ((coordinate as List<dynamic>)[0] as num).toDouble(),
            latitude: (coordinate[1] as num).toDouble(),
          ),
      ],
    );
  }

  /// Real driving/walking/cycling durations from [origin] to each of
  /// [destinations], in the same order. A null entry means Mapbox couldn't
  /// find a route (e.g. destination unreachable by road).
  ///
  /// Mapbox's Matrix API caps coordinates per request to 10 for
  /// driving-traffic and 25 for other profiles — keep the destination list
  /// under that limit for the chosen mode.
  Future<List<Duration?>> fetchDurations({
    required GeoPoint origin,
    required List<GeoPoint> destinations,
    required TransportMode mode,
  }) async {
    final coordinates = [origin, ...destinations]
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');
    final uri = Uri.parse('$_base/directions-matrix/v1/mapbox/${mode.mapboxProfile}/$coordinates')
        .replace(queryParameters: {'sources': '0', 'access_token': _accessToken});

    final json = await _getJson(uri);
    final durationsRow = (json['durations'] as List<dynamic>).first as List<dynamic>;
    return [
      for (final seconds in durationsRow.skip(1))
        seconds == null ? null : Duration(seconds: (seconds as num).round()),
    ];
  }

  /// A full route from [origin] to [destination], including turn-by-turn steps.
  Future<DirectionsRoute> fetchRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    required TransportMode mode,
  }) async {
    final coordinates =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.parse('$_base/directions/v5/mapbox/${mode.mapboxProfile}/$coordinates')
        .replace(queryParameters: {
      'geometries': 'geojson',
      'steps': 'true',
      'overview': 'full',
      'access_token': _accessToken,
    });

    final json = await _getJson(uri);
    final routes = json['routes'] as List<dynamic>;
    if (routes.isEmpty) {
      throw Exception('No route found between the selected points.');
    }
    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>;
    final steps = (legs.first as Map<String, dynamic>)['steps'] as List<dynamic>;

    return DirectionsRoute(
      points: [
        for (final coordinate in geometry['coordinates'] as List<dynamic>)
          GeoPoint(
            longitude: ((coordinate as List<dynamic>)[0] as num).toDouble(),
            latitude: (coordinate[1] as num).toDouble(),
          ),
      ],
      steps: [
        for (final step in steps)
          DirectionsStep(
            instruction: ((step as Map<String, dynamic>)['maneuver'] as Map<String, dynamic>)['instruction']
                as String,
            distanceMeters: (step['distance'] as num).toDouble(),
          ),
      ],
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
    );
  }
}
