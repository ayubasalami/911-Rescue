import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
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

  static JsonReader _reader(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw JsonFormatException(
        'responder endpoint: expected an object, got ${body.runtimeType}',
      );
    }
    return JsonReader(body);
  }
}
