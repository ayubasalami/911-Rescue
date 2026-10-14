import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { dev, staging, prod }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appDisplayName,
    required this.apiBaseUrl,
    required this.mapboxAccessToken,
    required this.googleServerClientId,
  });

  final AppEnvironment environment;
  final String appDisplayName;

  final String apiBaseUrl;
  final String mapboxAccessToken;

  /// The *web* OAuth client of this flavor's Firebase project. Google
  /// issues the sign-in ID token for this client, and it's the audience
  /// the backend checks.
  final String googleServerClientId;
}

final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError(
    'appConfigProvider must be overridden in bootstrap()',
  );
});
