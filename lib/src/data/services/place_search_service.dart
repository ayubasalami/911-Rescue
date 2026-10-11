import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/app_failure.dart';
import '../../core/env.dart';
import '../../core/result.dart';
import '../models/route_point.dart';

final placeSearchServiceProvider = Provider<PlaceSearchService>(
  (ref) => PlaceSearchService(),
);

/// General place/address search via OpenStreetMap's Nominatim — what the
/// web platform's Route Planner merges in alongside facility matches, so a
/// street or landmark can be an origin/destination, not just a facility.
///
/// Top 3, each named by the first two parts of its `display_name`, like
/// the web — but bounded to a Lagos State box rather than the web's
/// appended " Ikeja Lagos". Checked live: that suffix only matches places
/// actually in Ikeja ("Yaba", "Ojuelegba" both returned nothing), while
/// the bounded search finds them.
class PlaceSearchService {
  PlaceSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  DateTime? _lastRequest;

  /// Nominatim's usage policy caps clients at one request per second.
  static const _minInterval = Duration(seconds: 1);

  Future<Result<List<RoutePoint>>> search(String query) async {
    if (isTestEnvironment) return const Ok([]);

    final last = _lastRequest;
    if (last != null) {
      final wait = _minInterval - DateTime.now().difference(last);
      if (!wait.isNegative) await Future<void>.delayed(wait);
    }
    _lastRequest = DateTime.now();

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'q': query,
        'limit': '3',
        'countrycodes': 'ng',
        // Lagos State: west,north,east,south.
        'viewbox': '2.70,6.75,4.35,6.37',
        'bounded': '1',
      });
      final response = await _client.get(
        uri,
        // Required by Nominatim's usage policy — a browser sends its own
        // headers automatically; an app has to identify itself.
        headers: const {'User-Agent': '911Rescue-Mobile/1.0 (911rescueme.com)'},
      );
      if (response.statusCode != 200) {
        return Err(
          ServerFailure(
            message: 'Nominatim search failed (${response.statusCode})',
            statusCode: response.statusCode,
          ),
        );
      }
      final body = jsonDecode(response.body) as List<dynamic>;
      return Ok([
        for (final item in body.cast<Map<String, dynamic>>())
          RoutePoint(
            name: (item['display_name'] as String)
                .split(',')
                .take(2)
                .map((part) => part.trim())
                .join(', '),
            latitude: double.parse(item['lat'] as String),
            longitude: double.parse(item['lon'] as String),
          ),
      ]);
    } catch (e, st) {
      return Err(UnknownFailure(message: '$e', cause: e, stackTrace: st));
    }
  }
}
