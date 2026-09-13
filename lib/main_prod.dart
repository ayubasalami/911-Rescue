import 'src/bootstrap.dart';
import 'src/core/config/app_config.dart';

void main() async {
  await bootstrap(
    const AppConfig(
      environment: AppEnvironment.prod,
      appDisplayName: '911 Rescue',
      apiBaseUrl: 'https://api.911rescueme.com',
      mapboxAccessToken: String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
    ),
  );
}
