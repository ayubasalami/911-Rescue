import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_failure.dart';
import '../../core/config/app_config.dart';
import '../../core/result.dart';
import '../models/app_user.dart';
import '../network/cookie_jar_provider.dart';
import '../services/auth_service.dart';
import '../services/google_sign_in_service.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(authServiceProvider),
    ref.watch(googleSignInServiceProvider),
    ref.watch(cookieJarProvider),
    Uri.parse(ref.watch(appConfigProvider).apiBaseUrl),
  ),
);

/// The outcome of [AuthRepository.signIn].
sealed class SignInOutcome {
  const SignInOutcome();
}

class SignedIn extends SignInOutcome {
  const SignedIn(this.user);
  final AppUser user;
}

/// The user closed Google's account picker — show nothing.
class SignInCancelled extends SignInOutcome {
  const SignInCancelled();
}

class SignInFailed extends SignInOutcome {
  const SignInFailed(this.message, {required this.reason});
  final String message;

  /// A short code for analytics — see `AnalyticsEvents.loginFailed`.
  final String reason;
}

/// Native Google sign-in, exchanged for the backend's `session` cookie —
/// the same session the web login creates.
class AuthRepository {
  AuthRepository(this._service, this._google, this._cookies, this._apiHost);

  final AuthService _service;
  final GoogleSignInService _google;
  final CookieJar _cookies;
  final Uri _apiHost;

  Future<Result<AppUser?>> currentUser() => _service.status();

  Future<SignInOutcome> signIn() async {
    final String idToken;
    switch (await _google.signIn()) {
      case GoogleSignInSucceeded(:final identity):
        idToken = identity.idToken;
      case GoogleSignInCancelled():
        return const SignInCancelled();
      case GoogleSignInFailed(:final message):
        return SignInFailed(message, reason: 'google');
    }

    final AppFailure failure;
    switch (await _service.signInWithGoogle(idToken)) {
      case Ok(:final value):
        return SignedIn(value);
      case Err(failure: final error):
        failure = error;
    }
    // Forget the Google account too, so the next attempt shows the picker
    // again rather than silently reusing the one that just failed.
    await _google.signOut().catchError((Object _) {});
    return switch (failure) {
      // The backend couldn't reach Google to check the token — not the
      // user's fault, and not a credentials problem.
      ServerFailure(statusCode: 503) => const SignInFailed(
        'Couldn\'t reach Google to confirm your sign-in. Please try again.',
        reason: 'google_unreachable',
      ),
      UnauthorizedFailure() => const SignInFailed(
        'Google sign-in was rejected. Please try again.',
        reason: 'rejected',
      ),
      NetworkFailure() ||
      TimeoutFailure() => SignInFailed(failure.userMessage, reason: 'network'),
      _ => SignInFailed(failure.userMessage, reason: 'server'),
    };
  }

  /// Ends the session everywhere it lives: the server, the cookie jar and
  /// Google. Never fails — locally the user is signed out regardless.
  Future<void> signOut() async {
    await _service.signOut();
    await _cookies.delete(_apiHost);
    await _google.signOut().catchError((Object _) {});
  }
}
