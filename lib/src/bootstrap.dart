import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../firebase_options_dev.dart' as dev_firebase;
import '../firebase_options_prod.dart' as prod_firebase;
import '../firebase_options_staging.dart' as staging_firebase;
import 'app.dart';
import 'core/config/app_config.dart';
import 'data/network/cookie_jar_provider.dart';

/// dev and staging both live in the `rescue-staging` Firebase project (as
/// separate apps, since their bundle IDs differ); prod has its own project.
FirebaseOptions _firebaseOptionsFor(AppEnvironment environment) =>
    switch (environment) {
      AppEnvironment.dev => dev_firebase.DefaultFirebaseOptions.currentPlatform,
      AppEnvironment.staging =>
        staging_firebase.DefaultFirebaseOptions.currentPlatform,
      AppEnvironment.prod =>
        prod_firebase.DefaultFirebaseOptions.currentPlatform,
    };

Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: _firebaseOptionsFor(config.environment),
  );
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
