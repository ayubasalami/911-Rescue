import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { dev, staging, prod }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appDisplayName,
    required this.apiBaseUrl,
    required this.mapboxAccessToken,
    required this.googleServerClientId,
    this.appleSignInEnabled = false,
  });

  final AppEnvironment environment;
  final String appDisplayName;

  final String apiBaseUrl;
  final String mapboxAccessToken;

  /// The *web* OAuth client of this flavor's Firebase project. Google
  /// issues the sign-in ID token for this client, and it's the audience
  /// the backend checks.
  final String googleServerClientId;

  /// Shows "Sign in with Apple" (iOS only). Off for public prod builds
  /// until the backend's Apple credentials are live: before then the
  /// sign-in's one-time code can't be exchanged, so the account could never
  /// have its Apple token revoked on deletion. Prod turns it on only with
  /// `--dart-define=APPLE_SIGN_IN=true`, for internal test builds.
  final bool appleSignInEnabled;
}

final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError(
    'appConfigProvider must be overridden in bootstrap()',
  );
});
