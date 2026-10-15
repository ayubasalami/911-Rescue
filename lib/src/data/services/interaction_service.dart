import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../models/facility.dart';
import '../network/api_client.dart';

final interactionServiceProvider = Provider<InteractionService>(
  (ref) => InteractionService(ref.watch(apiClientProvider)),
);

/// What the user did with a facility — the web's `interaction_type`s,
/// which feed the dashboard's Recent Activity and Most Visited.
enum FacilityInteraction { navigated, analyzed }

/// Records facility activity against the signed-in account
/// (`/api/log_interaction`). Needs the session cookie.
class InteractionService {
  InteractionService(this._api);

  final ApiClient _api;

  Future<Result<void>> log(Facility facility, FacilityInteraction type) =>
      _api.post(
        '/api/log_interaction',
        body: {
          'facility_name': facility.name,
          'facility_category': facility.rawCategory ?? facility.categoryLabel,
          'lat': facility.latitude,
          'lng': facility.longitude,
          'interaction_type': type.name,
        },
        parse: (_) {},
      );
}
