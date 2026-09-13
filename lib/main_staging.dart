import 'src/bootstrap.dart';
import 'src/core/config/app_config.dart';

void main() async {
  await bootstrap(
    const AppConfig(
      environment: AppEnvironment.staging,
      appDisplayName: '911 Rescue Staging',
      apiBaseUrl: 'https://api.911rescueme.com',
      mapboxAccessToken: String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
    ),
  );
}
