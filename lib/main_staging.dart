import 'src/bootstrap.dart';
import 'src/core/config/app_config.dart';

void main() {
  bootstrap(
    const AppConfig(
      environment: AppEnvironment.staging,
      appDisplayName: '911 Rescue Staging',
      apiBaseUrl: 'example.com',
      mapboxAccessToken: String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
    ),
  );
}
