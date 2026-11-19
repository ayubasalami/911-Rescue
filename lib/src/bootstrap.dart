import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options_dev.dart' as dev_firebase;
import '../firebase_options_prod.dart' as prod_firebase;
import '../firebase_options_staging.dart' as staging_firebase;
import 'app.dart';
import 'core/config/app_config.dart';
import 'data/network/api_client.dart' show apiClientName;
import 'data/network/cookie_jar_provider.dart';
import 'data/repositories/role_repository.dart';
import 'data/repositories/theme_repository.dart';
import 'data/services/analytics_service.dart';
import 'data/services/crash_reporting_service.dart';
import 'data/services/kpi_tracker.dart';
import 'ui/core/view_model/role_view_model.dart';
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
  final role = await RoleRepository().load();
  final appVersion = config.analyticsEnabled
      ? await _analyticsVersion(config)
      : '';
  final kpiTracker = config.analyticsEnabled
      ? await _startKpiTracker(config, appVersion)
      : null;
  final posthog = config.analyticsEnabled
      ? await _startPostHog(config, appVersion)
      : null;
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        cookieJarProvider.overrideWithValue(cookieJar),
        crashReportingServiceProvider.overrideWithValue(crashReporting),
        initialThemeModeProvider.overrideWithValue(themeMode),
        initialRoleProvider.overrideWithValue(role),
        kpiTrackerProvider.overrideWithValue(kpiTracker),
        posthogProvider.overrideWithValue(posthog),
      ],
      child: const App(),
    ),
  );
}

/// The app version analytics report, with `-staging` on staging builds so
/// test use can be filtered out.
Future<String> _analyticsVersion(AppConfig config) async {
  final info = await PackageInfo.fromPlatform();
  return config.environment == AppEnvironment.staging
      ? '${info.version}-staging'
      : info.version;
}

/// The backend's KPI tracker.
Future<KpiTracker> _startKpiTracker(AppConfig config, String appVersion) async {
  final view = PlatformDispatcher.instance.views.first;
  final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
  final tracker = KpiTracker(
    dio: Dio(BaseOptions(baseUrl: config.apiBaseUrl)),
    prefs: await SharedPreferences.getInstance(),
    platform: apiClientName,
    appVersion: appVersion,
    device: shortestSide >= 600 ? 'tablet' : 'mobile',
  )..load();
  tracker.start();
  return tracker;
}

/// The web app's PostHog project, set up as the backend's tracking spec
/// asks: named events only, no session replay (screens can show medical
/// details and live locations), and profiles for signed-in users only.
Future<Posthog?> _startPostHog(AppConfig config, String appVersion) async {
  if (config.posthogApiKey.isEmpty) return null;
  final posthogConfig = PostHogConfig(config.posthogApiKey)
    ..host = config.posthogHost
    ..captureApplicationLifecycleEvents = true
    ..personProfiles = PostHogPersonProfiles.identifiedOnly
    ..sessionReplay = false
    ..surveys = false
    ..preloadFeatureFlags = false
    ..capturePushNotificationSubscriptions = false
    ..capturePushNotificationOpened = false
    ..debug = kDebugMode;
  final posthog = Posthog();
  try {
    await posthog.setup(posthogConfig);
    await posthog.register('platform', apiClientName);
    await posthog.register('app', 'mobile');
    await posthog.register('app_version', appVersion);
    if (config.environment == AppEnvironment.staging) {
      await posthog.register('env', 'staging');
    }
  } catch (e) {
    debugPrint('[posthog] setup: $e');
    return null;
  }
  // Sends what's queued before the OS can suspend the app.
  AppLifecycleListener(
    onPause: () => posthog.flush().catchError((Object _) {}),
  );
  return posthog;
}
