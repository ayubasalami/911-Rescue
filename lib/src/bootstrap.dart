import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options_dev.dart' as dev_firebase;
import '../firebase_options_prod.dart' as prod_firebase;
import '../firebase_options_staging.dart' as staging_firebase;
import 'app.dart';
import 'core/config/app_config.dart';
import 'data/network/api_client.dart' show apiClientName;
import 'data/network/cookie_jar_provider.dart';
import 'data/repositories/theme_repository.dart';
import 'data/services/analytics_service.dart';
import 'data/services/crash_reporting_service.dart';
import 'data/services/kpi_tracker.dart';
import 'ui/core/view_model/theme_mode_view_model.dart';

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
  // Both of Flutter's global error entry points: framework errors (build,
  // layout, paint) and uncaught async errors.
  final crashReporting = CrashReportingService.create();
  FlutterError.onError = crashReporting.recordFlutterError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashReporting.recordError(error, stack, fatal: true);
    return true;
  };
  assert(
    config.mapboxAccessToken.isNotEmpty,
    'MAPBOX_ACCESS_TOKEN is empty — run/build with '
    '--dart-define-from-file=dart_defines.json (see dart_defines.example.json).',
  );
  MapboxOptions.setAccessToken(config.mapboxAccessToken);
  final cookieJar = await createCookieJar();
  final themeMode = await ThemeRepository().load();
  final kpiTracker = config.analyticsEnabled
      ? await _startKpiTracker(config)
      : null;
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        cookieJarProvider.overrideWithValue(cookieJar),
        crashReportingServiceProvider.overrideWithValue(crashReporting),
        initialThemeModeProvider.overrideWithValue(themeMode),
        kpiTrackerProvider.overrideWithValue(kpiTracker),
      ],
      child: const App(),
    ),
  );
}

/// The backend's KPI tracker, with the version staging builds report under
/// (`-staging`) so the dashboard can filter test use out.
Future<KpiTracker> _startKpiTracker(AppConfig config) async {
  final info = await PackageInfo.fromPlatform();
  final view = PlatformDispatcher.instance.views.first;
  final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
  final tracker = KpiTracker(
    dio: Dio(BaseOptions(baseUrl: config.apiBaseUrl)),
    prefs: await SharedPreferences.getInstance(),
    platform: apiClientName,
    appVersion: config.environment == AppEnvironment.staging
        ? '${info.version}-staging'
        : info.version,
    device: shortestSide >= 600 ? 'tablet' : 'mobile',
  )..load();
  tracker.start();
  return tracker;
}
