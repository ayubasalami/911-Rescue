import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../models/app_user.dart';
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
  AnalyticsService(this._analytics, {this._kpi, this._posthog});

  factory AnalyticsService.create({KpiTracker? kpi, Posthog? posthog}) {
    final analytics = Firebase.apps.isNotEmpty
        ? FirebaseAnalytics.instance
        : null;
    analytics?.setAnalyticsCollectionEnabled(true);
    return AnalyticsService(analytics, kpi: kpi, posthog: posthog);
  }

  final FirebaseAnalytics? _analytics;

  /// Null where tracking is off (dev builds, tests).
  final KpiTracker? _kpi;
  final Posthog? _posthog;

  /// Visit bookkeeping for the KPI dashboard; PostHog keeps its own.
  static const _kpiOnly = {
    'session_start',
    'app_open',
    'heartbeat',
    'screen_view',
  };

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
  /// Whether this device is being used as a responder's: the tracking spec
  /// keeps staff screens out of the KPIs and PostHog, so nothing is sent
  /// to either while set.
  bool _paused = false;

  void setPaused(bool paused) {
    if (paused == _paused) return;
    _paused = paused;
    _kpi?.paused = paused;
    _quietly(paused ? _posthog?.optOut() : _posthog?.optIn(), 'pause');
  }

  void track(String name, [Map<String, Object>? props]) {
    if (_paused) return;
    _kpi?.track(name, props);
    if (_kpiOnly.contains(name)) return;
    _quietly(_posthog?.capture(eventName: name, properties: props), name);
  }

  /// A main screen shown: PostHog's screen view and the dashboard's
  /// `screen_view`.
  void screen(String name) {
    if (_paused) return;
    _quietly(_posthog?.screen(screenName: name), 'screen');
    _kpi?.track('screen_view', {'screen': name});
  }

  /// Signed in, now or from a saved session: one PostHog profile per person
  /// across web and mobile, by email only.
  void identify(AppUser user) {
    _kpi?.signedIn = true;
    _quietly(
      _posthog?.identify(
        userId: user.email,
        userProperties: {'email': user.email, 'name': user.name ?? ''},
      ),
      'identify',
    );
  }

  void signedOut() {
    _kpi?.signedIn = false;
    _quietly(_posthog?.reset(), 'reset');
  }

  /// After [AnalyticsEvents.accountDeleted]: sends what's queued under the
  /// old install id, then starts a new one.
  Future<void> accountDeleted() async {
    await _kpi?.flush();
    signedOut();
    await _kpi?.resetIdentity();
  }

  void _quietly(Future<void>? call, String name) =>
      call?.catchError((Object e) => debugPrint('[posthog] $name: $e'));

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
final posthogProvider = Provider<Posthog?>((ref) => null);

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService.create(
    kpi: ref.watch(kpiTrackerProvider),
    posthog: ref.watch(posthogProvider),
  );
});
