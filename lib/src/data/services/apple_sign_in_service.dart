import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// What Apple's native sheet hands back, for the backend to verify.
class AppleIdentity {
  const AppleIdentity({
    required this.identityToken,
    required this.authorizationCode,
    this.fullName,
  });

  final String identityToken;

  /// Single-use, valid ~5 minutes — the backend exchanges it at sign-in so
  /// the account's Apple token can be revoked if it's deleted.
  final String authorizationCode;

  /// Only present on the user's first Apple sign-in to this app; the
  /// backend keeps it.
  final String? fullName;
}

/// The outcome of [AppleSignInService.signIn].
sealed class AppleSignInOutcome {
  const AppleSignInOutcome();
}

class AppleSignInSucceeded extends AppleSignInOutcome {
  const AppleSignInSucceeded(this.identity);
  final AppleIdentity identity;
}

/// The user closed Apple's sheet — not an error, show nothing.
class AppleSignInCancelled extends AppleSignInOutcome {
  const AppleSignInCancelled();
}

class AppleSignInFailed extends AppleSignInOutcome {
  const AppleSignInFailed(this.message);
  final String message;
}

/// Native Sign in with Apple (iOS). Asks for name and email; the token's
/// audience is the app's bundle ID, which the backend accepts per flavor.
class AppleSignInService {
  const AppleSignInService();

  Future<AppleSignInOutcome> signIn() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = credential.identityToken;
      if (token == null) {
        return const AppleSignInFailed(
          'Apple sign-in did not return an identity token.',
        );
      }
      final name = [
        ?credential.givenName,
        ?credential.familyName,
      ].join(' ').trim();
      return AppleSignInSucceeded(
        AppleIdentity(
          identityToken: token,
          authorizationCode: credential.authorizationCode,
          fullName: name.isEmpty ? null : name,
        ),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AppleSignInCancelled();
      }
      debugPrint('[apple_sign_in] ${e.code}: ${e.message}');
      return const AppleSignInFailed(
        'Could not sign in with Apple. Please try again.',
      );
    } catch (e) {
      debugPrint('[apple_sign_in] $e');
      return const AppleSignInFailed(
        'Could not sign in with Apple. Please try again.',
      );
    }
  }
}

final appleSignInServiceProvider = Provider<AppleSignInService>(
  (ref) => const AppleSignInService(),
);
