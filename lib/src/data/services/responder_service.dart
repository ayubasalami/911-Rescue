import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../models/geo_point.dart';
import '../models/responder.dart';
import '../network/api_client.dart';
import '../network/json_reader.dart';

final responderServiceProvider = Provider<ResponderService>(
  (ref) => ResponderService(ref.watch(apiClientProvider)),
);

/// The API's responder endpoints. Responders sign in with an ID and
/// password issued to them, separate from the public Google sign-in; the
/// session is a cookie, kept alongside the public user's in the same jar.
class ResponderService {
  ResponderService(this._api);

  final ApiClient _api;

  /// Wrong details come back as the server's own message ("Incorrect
  /// responder ID or password"). Rate limited to 5 a minute, 10 an hour.
  Future<Result<Responder>> login({
    required String responderId,
    required String password,
  }) => _api.post<Responder>(
    '/api/responder/login',
    body: {'responder_id': responderId, 'password': password},
    parse: (body) => Responder.fromJson(_reader(body).object('responder')),
  );

  /// Also ends duty and clears the stored position on the server.
  Future<Result<void>> logout() =>
      _api.post<void>('/api/responder/logout', body: const {}, parse: (_) {});

  /// The signed-in responder, or null. Safe to call when signed out: the
  /// server answers `logged_in: false` rather than 401.
  Future<Result<Responder?>> status() => _api.get<Responder?>(
    '/api/responder/status',
    parse: (body) {
      final r = _reader(body);
      if (!r.boolOr('logged_in', fallback: false)) return null;
      return Responder.fromJson(r.object('responder'));
    },
  );

  /// Only on-duty responders receive dispatch. Going off duty clears the
  /// stored position. Returns the duty the server now has.
  Future<Result<bool>> setDuty(bool onDuty) => _api.post<bool>(
    '/api/responder/duty',
    body: {'on_duty': onDuty},
    parse: (body) => _reader(body).boolOr('on_duty', fallback: onDuty),
  );

  /// The position heartbeat. Rejected unless on duty; the server ignores
  /// fixes worse than 500 m.
  Future<Result<void>> sendLocation(GeoPoint point, double accuracy) =>
      _api.post<void>(
        '/api/responder/location',
        body: {
          'lat': point.latitude,
          'lng': point.longitude,
          'accuracy': accuracy,
        },
        parse: (_) {},
      );

  /// The dispatch queue: unclaimed pings for their agency plus their own.
  /// Off duty, the server answers with an empty list.
  Future<Result<List<ResponderPing>>> pings() => _api.get<List<ResponderPing>>(
    '/api/responder/pings',
    parse: (body) =>
        _reader(body).list('pings', ResponderPing.fromJson).toList(),
  );

  /// Claiming is a race: a responder who loses gets `ConflictFailure` (409)
  /// and should see the queue refreshed, not retry.
  Future<Result<void>> accept(int pingId) => _api.post<void>(
    '/api/responder/pings/$pingId/accept',
    body: const {},
    parse: (_) {},
  );

  /// How they're travelling — drives the ETA the waiting citizen sees.
  Future<Result<void>> setMode(int pingId, String mode) => _api.post<void>(
    '/api/responder/pings/$pingId/mode',
    body: {'mode': mode},
    parse: (_) {},
  );

  /// `en_route`, `arrived` or `resolved`.
  Future<Result<void>> setStatus(int pingId, String status) => _api.post<void>(
    '/api/responder/pings/$pingId/status',
    body: {'status': status},
    parse: (_) {},
  );

  /// Pings they've handled, with totals.
  Future<Result<ResponderHistory>> history() => _api.get<ResponderHistory>(
    '/api/responder/history',
    parse: (body) => ResponderHistory.fromJson(_reader(body)),
  );

  /// Plays the citizen's voice note; the token is in the query string
  /// because media players don't send the session cookie.
  static String voiceUrl(String apiBaseUrl, String publicId) {
    final id = Uri.encodeComponent(publicId);
    return '$apiBaseUrl/api/ping/$id/voice?token=$id';
  }

  static JsonReader _reader(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw JsonFormatException(
        'responder endpoint: expected an object, got ${body.runtimeType}',
      );
    }
    return JsonReader(body);
  }
}
