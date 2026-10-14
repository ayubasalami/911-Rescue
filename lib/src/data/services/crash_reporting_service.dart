import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper around [FirebaseCrashlytics.instance].
///
/// Every method is a no-op when no Firebase app was initialized — e.g.
/// under `flutter test`. Collection is off in debug builds; errors are
/// still printed locally either way, so nothing is lost silently.
class CrashReportingService {
  CrashReportingService(this._crashlytics);

  factory CrashReportingService.create() {
    final crashlytics = Firebase.apps.isNotEmpty
        ? FirebaseCrashlytics.instance
        : null;
    crashlytics?.setCrashlyticsCollectionEnabled(!kDebugMode);
    return CrashReportingService(crashlytics);
  }

  final FirebaseCrashlytics? _crashlytics;

  /// Replaces `FlutterError.onError` entirely, so it must also do what the
  /// default handler does — [FlutterError.presentError] dumps the error to
  /// the console — or every Flutter error would go unlogged locally.
  void recordFlutterError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _crashlytics?.recordFlutterError(details);
  }

  /// Uncaught async errors (`PlatformDispatcher.onError`) and unexpected
  /// failures caught on purpose (non-fatal, e.g. [ApiClient]'s parse
  /// errors).
  Future<void> recordError(
    Object exception,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) {
    debugPrint('[error] $exception\n$stackTrace');
    final crashlytics = _crashlytics;
    if (crashlytics == null) return Future.value();
    return crashlytics.recordError(exception, stackTrace, fatal: fatal);
  }

  /// A real native crash, so Crashlytics alerting can be checked end to
  /// end. Staging only (see [StagingTestCrashButton]); the report is sent
  /// on the next launch.
  void forceCrash() => _crashlytics?.crash();

  Future<void> log(String message) {
    final crashlytics = _crashlytics;
    if (crashlytics == null) return Future.value();
    return crashlytics.log(message);
  }

  Future<void> setCustomKey(String key, Object value) {
    final crashlytics = _crashlytics;
    if (crashlytics == null) return Future.value();
    return crashlytics.setCustomKey(key, value);
  }

  /// Attach an internal account id to crash reports (never PII); `''`
  /// clears it.
  Future<void> setUserId(String id) {
    final crashlytics = _crashlytics;
    if (crashlytics == null) return Future.value();
    return crashlytics.setUserIdentifier(id);
  }
}

/// Overridden in `bootstrap()` with the instance the global error handlers
/// use, so the whole app shares one.
final crashReportingServiceProvider = Provider<CrashReportingService>((ref) {
  return CrashReportingService.create();
});
