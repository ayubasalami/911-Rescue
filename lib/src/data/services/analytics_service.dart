import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kpi_tracker.dart';

/// Thin wrapper around [FirebaseAnalytics.instance].
///
/// Every method is a no-op when no Firebase app was initialized — e.g.
/// under `flutter test`, which never runs `bootstrap()`.
///
/// Debug builds still collect, so events can be checked in DebugView:
/// iOS switches debug mode on in `AppDelegate.swift`; Android needs
/// `adb shell setprop debug.firebase.analytics.app <application id>`
/// (see README). Debug-mode events are kept out of the normal reports.
class AnalyticsService {
  AnalyticsService(this._analytics, {this._kpi});

  factory AnalyticsService.create({KpiTracker? kpi}) {
    final analytics = Firebase.apps.isNotEmpty
        ? FirebaseAnalytics.instance
        : null;
    analytics?.setAnalyticsCollectionEnabled(true);
    return AnalyticsService(analytics, kpi: kpi);
  }

  final FirebaseAnalytics? _analytics;

  /// Null where tracking is off (dev builds, tests).
  final KpiTracker? _kpi;

  NavigatorObserver get observer {
    final analytics = _analytics;
    return analytics != null
        ? FirebaseAnalyticsObserver(analytics: analytics)
        : NavigatorObserver();
  }

  /// Fire-and-forget — analytics must never hold up or break a user action.
  /// See [AnalyticsEvents] for names and their parameters.
  void logEvent(String name, {Map<String, Object>? parameters}) {
    final analytics = _analytics;
    if (analytics == null) return;
    analytics
        .logEvent(name: name, parameters: parameters)
        .catchError((Object e) => debugPrint('[analytics] $name: $e'));
  }

  /// One of the shared web and mobile events from the backend's tracking
  /// spec (`MOBILE_TRACKING_SPEC.md`), for its KPI dashboard. Same privacy
  /// rule as [logEvent]: no locations, search or symptom text, medical
  /// details or contact data.
  void track(String name, [Map<String, Object>? props]) =>
      _kpi?.track(name, props);

  /// Tie later events to an account. An internal id only (never PII);
  /// `null` clears it on sign-out.
  Future<void> setUserId(String? id) {
    final analytics = _analytics;
    if (analytics == null) return Future.value();
    return analytics.setUserId(id: id);
  }
}

/// Overridden in `bootstrap()` when [AppConfig.analyticsEnabled].
final kpiTrackerProvider = Provider<KpiTracker?>((ref) => null);

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService.create(kpi: ref.watch(kpiTrackerProvider));
});
