import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/result.dart';
import '../models/facility.dart';
import '../models/geo_point.dart';
import '../network/api_client.dart';
import '../network/json_reader.dart';

final facilityServiceProvider = Provider<FacilityService>(
  (ref) => FacilityService(ref.watch(apiClientProvider)),
);

/// Facility categories in the database are messy free text ("Primary
/// Health Center", "FRSC", "Maternity", …) — group them into the app's
/// five display categories the same way everywhere a raw string comes back
/// from the API (`/api/hospitals`, `/api/search_facilities`,
/// `/api/nearest_hospital`). Built from the actual live distribution (17
/// distinct raw values across ~2,900 facilities), not guessed.
FacilityCategory classifyFacilityCategory(String? raw) {
  // Normalized once up front rather than per-case: the live data has a
  // "Teaching/Tertiary Hospital" entry with a non-breaking space (U+00A0)
  // baked into the source text instead of a normal one, which a plain
  // string-literal case would silently miss.
  final normalized = raw?.replaceAll(' ', ' ').trim();
  switch (normalized) {
    case 'Police Station':
      return FacilityCategory.police;
    case 'Fire Station':
      return FacilityCategory.fire;
    case 'FRSC':
      return FacilityCategory.roadSafety;
    case 'Primary Health Center':
    case 'Primary Health Clinic':
    case 'General Hospital':
    case 'Medical Laboratory':
    case 'Health Post':
    case 'Maternity':
    case 'Pharmacy':
    case 'Dental Clinic':
    case 'Eye Clinic':
    case 'Specialist Hospital':
    case 'Specialized Hospital':
    case 'Teaching/Tertiary Hospital':
      return FacilityCategory.health;
    // Includes the literal 'Other' value and anything unrecognized.
    default:
      return FacilityCategory.other;
  }
}

/// Thin client over the 911 Rescue API's public facility/boundary
/// endpoints — no authentication required for any of these.
class FacilityService {
  FacilityService(this._api);

  final ApiClient _api;

  List<Facility>? _cachedFacilities;
  DateTime? _cachedAt;

  /// Matches the backend's own cache window ("Cached server side for 30
  /// minutes; cache it client side too") — refetching more often than the
  /// server itself refreshes would just hit a server cache anyway.
  static const _cacheTtl = Duration(minutes: 30);

  /// All ~2,900 Lagos facilities from `/api/hospitals` (a GeoJSON
  /// `FeatureCollection` despite the endpoint name — it covers every
  /// category, not just hospitals). Cached in memory for [_cacheTtl];
  /// pass [forceRefresh] to bypass that (e.g. a manual pull-to-refresh).
  Future<Result<List<Facility>>> fetchAllFacilities({
    bool forceRefresh = false,
  }) async {
    // The real endpoint returns ~2,900 facilities — under flutter_test
    // there's no real network anyway, so this fails fast instead of
    // letting the retry/backoff cycle run out the clock on the test.
    if (isTestEnvironment) return const Ok([]);

    final cachedAt = _cachedAt;
    if (!forceRefresh &&
        _cachedFacilities != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl) {
      return Ok(_cachedFacilities!);
    }

    final result = await _api.get<List<Facility>>(
      '/api/hospitals',
      parse: (body) {
        if (body is! Map<String, dynamic>) {
          throw JsonFormatException(
            'GET /api/hospitals: expected a FeatureCollection object, got ${body.runtimeType}',
          );
        }
        final r = JsonReader(body);
        return r.list('features', _facilityFromFeature);
      },
    );
    if (result case Ok(:final value)) {
      _cachedFacilities = value;
      _cachedAt = DateTime.now();
    }
    return result;
  }

  Facility _facilityFromFeature(JsonReader feature) {
    final coordinates = feature.object('geometry').rawList('coordinates');
    final lng = (coordinates[0] as num).toDouble();
    final lat = (coordinates[1] as num).toDouble();
    final properties = feature.object('properties');
    final name = properties.string('name');
    return Facility(
      id: _syntheticId(name, lat, lng),
      name: name,
      category: classifyFacilityCategory(properties.stringOrNull('category')),
      latitude: lat,
      longitude: lng,
      address: properties.stringOrNull('address'),
      phone: properties.stringOrNull('phone_number'),
    );
  }

  Future<Result<List<Facility>>> searchFacilities(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || isTestEnvironment) return Future.value(const Ok([]));
    return _api.get<List<Facility>>(
      '/api/search_facilities',
      query: {'q': trimmed},
      parse: (body) {
        if (body is! Map<String, dynamic>) {
          throw JsonFormatException(
            'GET /api/search_facilities: expected an object, got ${body.runtimeType}',
          );
        }
        final r = JsonReader(body);
        return r.list('results', _facilityFromSearchResult);
      },
    );
  }

  Facility _facilityFromSearchResult(JsonReader r) {
    final name = r.string('name');
    final lat = r.double_('lat');
    final lng = r.double_('lng');
    return Facility(
      id: _syntheticId(name, lat, lng),
      name: name,
      category: classifyFacilityCategory(r.stringOrNull('category')),
      latitude: lat,
      longitude: lng,
    );
  }

  /// Nearest facility to [point] by straight-line distance — the backend's
  /// own computation, not a client-side scan.
  Future<Result<Facility>> nearestFacility(GeoPoint point) {
    return _api.get<Facility>(
      '/api/nearest_hospital',
      query: {'lat': point.latitude, 'lng': point.longitude},
      parse: (body) {
        if (body is! Map<String, dynamic>) {
          throw JsonFormatException(
            'GET /api/nearest_hospital: expected an object, got ${body.runtimeType}',
          );
        }
        final r = JsonReader(body);
        final name = r.string('name');
        final lat = r.double_('lat');
        final lng = r.double_('lng');
        return Facility(
          id: _syntheticId(name, lat, lng),
          name: name,
          category: classifyFacilityCategory(r.stringOrNull('category')),
          latitude: lat,
          longitude: lng,
        );
      },
    );
  }

  /// The outer ring of the Lagos state boundary polygon, for the drawer's
  /// "Lagos Boundary" map layer. Confirmed live: a single `Polygon`
  /// feature, one ring — not a `MultiPolygon`, so this doesn't handle that
  /// case.
  Future<Result<List<GeoPoint>>> fetchBoundary() {
    return _api.get<List<GeoPoint>>(
      '/api/boundary',
      parse: (body) {
        if (body is! Map<String, dynamic>) {
          throw JsonFormatException(
            'GET /api/boundary: expected a FeatureCollection object, got ${body.runtimeType}',
          );
        }
        final r = JsonReader(body);
        final features = r.list('features', (f) => f);
        if (features.isEmpty) {
          throw JsonFormatException(
            'GET /api/boundary: expected at least one feature',
          );
        }
        final geometry = features.first.object('geometry');
        final outerRing =
            geometry.rawList('coordinates').first as List<dynamic>;
        return [
          for (final coordinate in outerRing)
            GeoPoint(
              longitude: ((coordinate as List<dynamic>)[0] as num).toDouble(),
              latitude: (coordinate[1] as num).toDouble(),
            ),
        ];
      },
    );
  }

  /// No stable id comes back from any of these endpoints — name +
  /// coordinates is unique enough in practice and, unlike a hash, can't
  /// collide.
  String _syntheticId(String name, double lat, double lng) => '$name|$lat|$lng';
}
