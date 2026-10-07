import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../models/ping.dart';
import '../models/triage.dart';
import '../network/api_client.dart';
import '../network/json_reader.dart';

final triageServiceProvider = Provider<TriageService>(
  (ref) => TriageService(ref.watch(apiClientProvider)),
);

/// `POST /api/triage_symptoms` — rate limited to 30/minute, 200/hour.
class TriageService {
  TriageService(this._api);

  final ApiClient _api;

  Future<Result<TriageAssessment>> assessSymptoms(String symptoms) {
    return _api.post<TriageAssessment>(
      '/api/triage_symptoms',
      body: {'symptoms': symptoms},
      parse: (body) {
        if (body is! Map<String, dynamic>) {
          throw JsonFormatException(
            'POST /api/triage_symptoms: expected an object, got ${body.runtimeType}',
          );
        }
        final r = JsonReader(body);
        final secondary = r.stringOrNull('secondary_agency');
        return TriageAssessment(
          source: TriageSource.fromApi(r.string('source')),
          agency: PingAgencyApi.fromApi(r.string('agency')),
          department: r.stringOrNull('department'),
          secondaryAgency: secondary == null
              ? null
              : PingAgencyApi.fromApi(secondary),
          isEmergency: r.boolOr('is_emergency', fallback: false),
          urgency: r.string('urgency'),
          sensitive: r.boolOr('sensitive', fallback: false),
          message: r.string('message'),
        );
      },
    );
  }
}
