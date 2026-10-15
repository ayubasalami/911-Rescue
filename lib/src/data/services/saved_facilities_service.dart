import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../models/saved_facility.dart';
import '../network/api_client.dart';
import '../network/json_reader.dart';

final savedFacilitiesServiceProvider = Provider<SavedFacilitiesService>(
  (ref) => SavedFacilitiesService(ref.watch(apiClientProvider)),
);

/// The account's saved facilities — needs the signed-in `session` cookie.
class SavedFacilitiesService {
  SavedFacilitiesService(this._api);

  final ApiClient _api;

  /// `ON CONFLICT DO NOTHING` on the server, so saving twice is harmless.
  Future<Result<void>> save(SavedFacility facility) => _api.post(
    '/api/save_facility',
    body: {
      'facility_name': facility.name,
      'facility_category': facility.category,
      'lat': facility.latitude,
      'lng': facility.longitude,
    },
    parse: (_) {},
  );

  Future<Result<void>> unsave(String name) => _api.post(
    '/api/unsave_facility',
    body: {'facility_name': name},
    parse: (_) {},
  );

  /// The `saved` list from `/api/my_dashboard`.
  Future<Result<List<SavedFacility>>> fetchSaved() => _api.get(
    '/api/my_dashboard',
    parse: (body) => JsonReader(
      body! as Map<String, dynamic>,
    ).list('saved', SavedFacility.fromServer),
  );
}
