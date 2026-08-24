import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { dev, staging, prod }


class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appDisplayName,
    required this.apiBaseUrl,
    required this.mapboxAccessToken,
  });

  final AppEnvironment environment;
  final String appDisplayName;


  final String apiBaseUrl;
  final String mapboxAccessToken;
}


final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be overridden in bootstrap()');
});
