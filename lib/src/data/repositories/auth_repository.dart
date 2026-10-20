import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_failure.dart';
import '../../core/config/app_config.dart';
import '../../core/result.dart';
import '../models/app_user.dart';
import '../network/cookie_jar_provider.dart';
import '../services/apple_sign_in_service.dart';
import '../services/auth_service.dart';
import '../services/google_sign_in_service.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(authServiceProvider),
    ref.watch(googleSignInServiceProvider),
    ref.watch(cookieJarProvider),
    Uri.parse(ref.watch(appConfigProvider).apiBaseUrl),
    apple: ref.watch(appleSignInServiceProvider),
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

/// The user closed Google's picker or Apple's sheet — show nothing.
class SignInCancelled extends SignInOutcome {
  const SignInCancelled();
}

class SignInFailed extends SignInOutcome {
  const SignInFailed(this.message, {required this.reason});
  final String message;

  /// A short code for analytics — see `AnalyticsEvents.loginFailed`.
  final String reason;
}

/// Native Google or Apple sign-in, exchanged for the backend's `session`
/// cookie — the same session the web login creates.
class AuthRepository {
  AuthRepository(
    this._service,
    this._google,
    this._cookies,
    this._apiHost, {
    this._apple = const AppleSignInService(),
  });

  final AuthService _service;
  final GoogleSignInService _google;
  final AppleSignInService _apple;
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
    return _failed(failure, provider: 'Google');
  }

  /// Sign in with Apple: Apple's native sheet, then the backend's
  /// `/auth/mobile/apple`, which sets the same session as Google.
  Future<SignInOutcome> signInWithApple() async {
    final AppleIdentity identity;
    switch (await _apple.signIn()) {
      case AppleSignInSucceeded(identity: final picked):
        identity = picked;
      case AppleSignInCancelled():
        return const SignInCancelled();
      case AppleSignInFailed(:final message):
        return SignInFailed(message, reason: 'apple');
    }
    return switch (await _service.signInWithApple(
      identityToken: identity.identityToken,
      authorizationCode: identity.authorizationCode,
      fullName: identity.fullName,
    )) {
      Ok(:final value) => SignedIn(value),
      Err(:final failure) => _failed(failure, provider: 'Apple'),
    };
  }

  /// [provider] is "Google" or "Apple".
  SignInFailed _failed(AppFailure failure, {required String provider}) =>
      switch (failure) {
        // The backend couldn't reach the provider to check the token — not
        // the user's fault, and not a credentials problem.
        ServerFailure(statusCode: 503) => SignInFailed(
          'Couldn\'t reach $provider to confirm your sign-in. Please try '
          'again.',
          reason: '${provider.toLowerCase()}_unreachable',
        ),
        UnauthorizedFailure() => SignInFailed(
          '$provider sign-in was rejected. Please try again.',
          reason: 'rejected',
        ),
        NetworkFailure() || TimeoutFailure() => SignInFailed(
          failure.userMessage,
          reason: 'network',
        ),
        _ => SignInFailed(failure.userMessage, reason: 'server'),
      };

  /// Deletes the account on the server (which also revokes any Apple
  /// token and ends the session), then clears it here too.
  Future<Result<void>> deleteAccount() async {
    final result = await _service.deleteAccount();
    if (result.isOk) {
      await _cookies.delete(_apiHost);
      await _google.signOut().catchError((Object _) {});
    }
    return result;
  }

  /// Ends the session everywhere it lives: the server, the cookie jar and
  /// Google. Never fails — locally the user is signed out regardless.
  Future<void> signOut() async {
    await _service.signOut();
    await _cookies.delete(_apiHost);
    await _google.signOut().catchError((Object _) {});
  }
}
