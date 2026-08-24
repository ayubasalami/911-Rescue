import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';


void bootstrap(AppConfig config) {
  WidgetsFlutterBinding.ensureInitialized();
  assert(
    config.mapboxAccessToken.isNotEmpty,
    'MAPBOX_ACCESS_TOKEN is empty — run/build with '
    '--dart-define-from-file=dart_defines.json (see dart_defines.example.json).',
  );
  MapboxOptions.setAccessToken(config.mapboxAccessToken);
  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const App(),
    ),
  );
}
