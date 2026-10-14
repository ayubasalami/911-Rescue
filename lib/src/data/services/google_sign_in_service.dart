import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_config.dart';

/// A Google account the user just picked, with the ID token the backend
/// exchanges for a session.
class GoogleIdentity {
  const GoogleIdentity({
    required this.email,
    required this.idToken,
    this.name,
    this.photoUrl,
  });

  final String email;
  final String? name;
  final String? photoUrl;
  final String idToken;
}

/// The outcome of [GoogleSignInService.signIn].
sealed class GoogleSignInOutcome {
  const GoogleSignInOutcome();
}

class GoogleSignInSucceeded extends GoogleSignInOutcome {
  const GoogleSignInSucceeded(this.identity);
  final GoogleIdentity identity;
}

/// The user closed the account picker — not an error, show nothing.
class GoogleSignInCancelled extends GoogleSignInOutcome {
  const GoogleSignInCancelled();
}

class GoogleSignInFailed extends GoogleSignInOutcome {
  const GoogleSignInFailed(this.message);
  final String message;
}

/// Native Google sign-in. The ID token is issued for the flavor's web
/// client ([AppConfig.googleServerClientId]) — the audience the backend
/// verifies. iOS also needs its own client ID, which comes from the
/// flavor's `GoogleService-Info.plist` via [FirebaseOptions.iosClientId];
/// Android finds its client from the package name and signing SHA-1.
class GoogleSignInService {
  GoogleSignInService(this._serverClientId);

  final String _serverClientId;
  Future<void>? _initialized;

  Future<void> _initialize() =>
      _initialized ??= GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS && Firebase.apps.isNotEmpty
            ? Firebase.app().options.iosClientId
            : null,
        serverClientId: _serverClientId,
      );

  Future<GoogleSignInOutcome> signIn() async {
    try {
      await _initialize();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return const GoogleSignInFailed(
          'Google sign-in did not return an ID token.',
        );
      }
      if (kDebugMode) _logTokenClaims(idToken);
      return GoogleSignInSucceeded(
        GoogleIdentity(
          email: account.email,
          name: account.displayName,
          photoUrl: account.photoUrl,
          idToken: idToken,
        ),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const GoogleSignInCancelled();
      }
      debugPrint('[google_sign_in] ${e.code}: ${e.description}');
      return const GoogleSignInFailed(
        'Could not sign in with Google. Please try again.',
      );
    } catch (e) {
      debugPrint('[google_sign_in] $e');
      return const GoogleSignInFailed(
        'Could not sign in with Google. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    await _initialize();
    await GoogleSignIn.instance.signOut();
  }

  /// Debug builds only: prints the claims the backend will check, so a
  /// wrong audience shows up here rather than as a mystery 401 later.
  void _logTokenClaims(String idToken) {
    try {
      final payload = idToken.split('.')[1];
      final claims =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(payload))),
              )
              as Map<String, dynamic>;
      debugPrint(
        '[google_sign_in] aud=${claims['aud']} iss=${claims['iss']} '
        'email_verified=${claims['email_verified']}',
      );
    } catch (_) {
      // Purely diagnostic.
    }
  }
}

final googleSignInServiceProvider = Provider<GoogleSignInService>((ref) {
  return GoogleSignInService(ref.watch(appConfigProvider).googleServerClientId);
});
