import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../models/dashboard.dart';
import '../network/api_client.dart';
import '../network/json_reader.dart';

final dashboardServiceProvider = Provider<DashboardService>(
  (ref) => DashboardService(ref.watch(apiClientProvider)),
);

class DashboardService {
  DashboardService(this._api);

  final ApiClient _api;

  /// Needs the signed-in session cookie.
  Future<Result<Dashboard>> fetch() => _api.get(
    '/api/my_dashboard',
    parse: (body) =>
        Dashboard.fromJson(JsonReader(body! as Map<String, dynamic>)),
  );
}
