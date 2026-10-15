import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/app_failure.dart';
import '../../core/config/app_config.dart';
import '../../core/result.dart';
import '../models/access_analysis.dart';
import '../models/geo_point.dart';
import '../network/api_client.dart';
import '../network/json_reader.dart';

final accessAnalysisServiceProvider = Provider<AccessAnalysisService>((ref) {
  return AccessAnalysisService(
    ref.watch(appConfigProvider).mapboxAccessToken,
    ref.watch(apiClientProvider),
  );
});

/// Directions and isochrones go through the 911 Rescue backend
/// (`/api/directions`, `/api/isochrones`) — it falls back to OSRM when
/// Mapbox itself can't find a route, and caches isochrones server-side.
/// The Matrix API (per-facility ETAs for the Accessibility Analyzer) has
/// no backend equivalent, so [fetchDurations] alone still calls Mapbox
/// directly with the same public access token used for the map.
class AccessAnalysisService {
  AccessAnalysisService(this._accessToken, this._api, {http.Client? client})
    : _client = client ?? http.Client();

  final String _accessToken;
  final ApiClient _api;
  final http.Client _client;

  static const _mapboxBase = 'https://api.mapbox.com';

  Future<Map<String, dynamic>> _getMapboxJson(Uri uri) async {
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Mapbox request failed (${response.statusCode}): ${response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Reachability polygons around [origin], up to 30 minutes — matches the
  /// fixed max band the web platform's legend has always shown, regardless
  /// of the Accessibility Analyzer's own (up to 60 min) threshold setting.
  ///
  /// Confirmed live: unlike two direct Mapbox isochrone calls (which used
  /// to give a clean 5/10/15/20/25/30 band set), this single backend call
  /// doesn't return evenly-spaced contours past 15 minutes — e.g.
  /// `max_time=30` comes back as `[5, 10, 15, 30]`, not all six. This
  /// renders whichever bands the backend actually returns rather than
  /// forcing a fixed set.
  Future<Result<List<IsochroneRing>>> fetchIsochrone({
    required GeoPoint origin,
    required TransportMode mode,
  }) {
    return _api.get<List<IsochroneRing>>(
      '/api/isochrones',
      query: {
        'lat': origin.latitude,
        'lng': origin.longitude,
        'max_time': 30,
        'mode': mode.backendMode,
      },
      parse: (body) {
        if (body is! Map<String, dynamic>) {
          throw JsonFormatException(
            'GET /api/isochrones: expected a FeatureCollection object, got ${body.runtimeType}',
          );
        }
        final r = JsonReader(body);
        return r.list('features', _isochroneRingFromFeature);
      },
    );
  }

  IsochroneRing _isochroneRingFromFeature(JsonReader feature) {
    final properties = feature.object('properties');
    final populationRaw = properties.stringOrNull('population');
    final population = (populationRaw == null || populationRaw == 'N/A')
        ? null
        : int.tryParse(populationRaw.replaceAll(',', ''));

    final outerRing =
        feature.object('geometry').rawList('coordinates').first
            as List<dynamic>;
    return IsochroneRing(
      minutes: properties.int_('time'),
      population: population,
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
  /// find a route. Still calls Mapbox's Matrix API directly — see the
  /// class doc for why.
  ///
  /// Mapbox's Matrix API caps coordinates per request to 10 for
  /// driving-traffic and 25 for other profiles — keep the destination list
  /// under that limit for the chosen mode (see
  /// `AccessAnalysisRepository._nearestFacilities`).
  Future<Result<List<Duration?>>> fetchDurations({
    required GeoPoint origin,
    required List<GeoPoint> destinations,
    required TransportMode mode,
  }) async {
    try {
      final coordinates = [
        origin,
        ...destinations,
      ].map((point) => '${point.longitude},${point.latitude}').join(';');
      final uri = Uri.parse(
        '$_mapboxBase/directions-matrix/v1/mapbox/${mode.mapboxProfile}/$coordinates',
      ).replace(queryParameters: {'sources': '0', 'access_token': _accessToken});

      final json = await _getMapboxJson(uri);
      final durationsRow =
          (json['durations'] as List<dynamic>).first as List<dynamic>;
      return Ok([
        for (final seconds in durationsRow.skip(1))
          seconds == null ? null : Duration(seconds: (seconds as num).round()),
      ]);
    } catch (e, st) {
      return Err(UnknownFailure(message: '$e', cause: e, stackTrace: st));
    }
  }

  /// A full route from [origin] to [destination], including turn-by-turn
  /// steps.
  Future<Result<DirectionsRoute>> fetchRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    required TransportMode mode,
  }) async {
    final result = await _api.get<DirectionsRoute>(
      '/api/directions',
      query: {
        'start_lat': origin.latitude,
        'start_lng': origin.longitude,
        'end_lat': destination.latitude,
        'end_lng': destination.longitude,
        'mode': mode.backendMode,
      },
      parse: (body) {
        if (body is! Map<String, dynamic>) {
          throw JsonFormatException(
            'GET /api/directions: expected an object, got ${body.runtimeType}',
          );
        }
        final r = JsonReader(body);
        final legs = r.list('legs', (leg) => leg);
        final steps = legs.isEmpty
            ? const <JsonReader>[]
            : legs.first.list('steps', (step) => step);
        final coordinates = r.object('geometry').rawList('coordinates');

        return DirectionsRoute(
          points: [
            for (final coordinate in coordinates)
              GeoPoint(
                longitude: ((coordinate as List<dynamic>)[0] as num).toDouble(),
                latitude: (coordinate[1] as num).toDouble(),
              ),
          ],
          steps: [for (final step in steps) _directionsStepFrom(step)],
          distanceMeters: r.double_('distance'),
          durationSeconds: r.double_('duration'),
          source: r.stringOrNull('source'),
        );
      },
    );

    // A 404 here is common and expected — both providers refuse long
    // walking/cycling requests (~24 km) — not a real error, so it gets a
    // clearer message than NotFoundFailure's generic default.
    if (result case Err(failure: NotFoundFailure())) {
      return const Err(
        RemoteFailure(
          message:
              'No route found for the selected mode — the destination may be too far.',
        ),
      );
    }
    return result;
  }

  DirectionsStep _directionsStepFrom(JsonReader step) {
    final maneuver = step.object('maneuver');
    final instruction = maneuver.stringOrNull('instruction');
    return DirectionsStep(
      instruction: instruction ?? _fallbackInstruction(maneuver, step),
      distanceMeters: step.double_('distance'),
    );
  }

  /// OSRM-sourced routes (the backend's fallback when Mapbox can't find
  /// one) don't include a human-readable `maneuver.instruction` the way
  /// Mapbox's own directions do — confirmed live: only `type`/`modifier`
  /// and the step's street `name`. This builds a plain-language
  /// instruction from those instead of leaving the step blank.
  String _fallbackInstruction(JsonReader maneuver, JsonReader step) {
    final type = maneuver.stringOrNull('type') ?? '';
    final modifier = maneuver.stringOrNull('modifier');
    final name = step.stringOrNull('name');
    final onStreet = (name != null && name.isNotEmpty) ? ' onto $name' : '';
    return switch (type) {
      'depart' => 'Head out$onStreet',
      'arrive' => 'Arrive at your destination',
      'roundabout' => 'Enter the roundabout',
      'exit roundabout' => 'Exit the roundabout$onStreet',
      'turn' =>
        modifier == 'uturn'
            ? 'Make a U-turn'
            : 'Turn ${modifier ?? ''}$onStreet'.trim(),
      'continue' => modifier == 'uturn' ? 'Make a U-turn' : 'Continue$onStreet',
      'merge' => 'Merge$onStreet',
      'on ramp' => 'Take the ramp',
      'off ramp' => 'Take the exit',
      'new name' => 'Continue$onStreet',
      'fork' => 'Keep ${modifier ?? 'straight'}$onStreet'.trim(),
      _ => (name != null && name.isNotEmpty) ? 'Continue on $name' : 'Continue',
    };
  }
}
