import 'src/bootstrap.dart';
import 'src/core/config/app_config.dart';

void main() {
  bootstrap(
    const AppConfig(
      environment: AppEnvironment.dev,
      appDisplayName: '911 Rescue Dev',
      apiBaseUrl: 'example.com',
      mapboxAccessToken: String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
    ),
  );
}
