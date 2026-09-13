import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/network/cookie_jar_provider.dart';

Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(
    config.mapboxAccessToken.isNotEmpty,
    'MAPBOX_ACCESS_TOKEN is empty — run/build with '
    '--dart-define-from-file=dart_defines.json (see dart_defines.example.json).',
  );
  MapboxOptions.setAccessToken(config.mapboxAccessToken);
  final cookieJar = await createCookieJar();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        cookieJarProvider.overrideWithValue(cookieJar),
      ],
      child: const App(),
    ),
  );
}
