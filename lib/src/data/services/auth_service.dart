import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../models/app_user.dart';
import '../network/api_client.dart';
import '../network/json_reader.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(apiClientProvider)),
);

/// The public-user session endpoints. The session is the same `session`
/// cookie the web login sets (30-day expiry), held by the app's cookie jar.
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  /// Exchanges a Google ID token for a session. 401 means the token was
  /// rejected; 503 means the server couldn't reach Google — retry, it's not
  /// an auth failure.
  Future<Result<AppUser>> signInWithGoogle(String idToken) => _api.post(
    '/auth/mobile/google',
    body: {'id_token': idToken},
    parse: (body) => AppUser.fromJson(
      JsonReader(body! as Map<String, dynamic>).object('user'),
    ),
  );

  /// Exchanges Apple's identity token (and one-time authorization code,
  /// which the backend trades for a revocable refresh token) for the same
  /// session. [fullName] only exists on the first Apple sign-in; the
  /// backend keeps it. Status codes as [signInWithGoogle].
  Future<Result<AppUser>> signInWithApple({
    required String identityToken,
    required String authorizationCode,
    String? fullName,
  }) => _api.post(
    '/auth/mobile/apple',
    body: {
      'identity_token': identityToken,
      'authorization_code': authorizationCode,
      'full_name': ?fullName,
    },
    parse: (body) => AppUser.fromJson(
      JsonReader(body! as Map<String, dynamic>).object('user'),
    ),
  );

  /// Deletes the signed-in account — profile, saved facilities and history
  /// — revokes any Apple token, and ends the session. 401 when not signed
  /// in.
  Future<Result<void>> deleteAccount() =>
      _api.post('/auth/delete_account', parse: (_) {});

  /// The signed-in user, or null when there's no (valid) session.
  Future<Result<AppUser?>> status() => _api.get(
    '/api/user_status',
    parse: (body) {
      final r = JsonReader(body! as Map<String, dynamic>);
      if (!r.boolOr('logged_in', fallback: false)) return null;
      final user = r.objectOrNull('user');
      return user == null ? null : AppUser.fromJson(user);
    },
  );

  /// Ends the session on the server. The response (a redirect for the web)
  /// doesn't matter.
  Future<Result<void>> signOut() => _api.get('/auth/logout', parse: (_) {});
}
