import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper around [FirebaseAnalytics.instance].
///
/// Every method is a no-op when no Firebase app was initialized — e.g.
/// under `flutter test`, which never runs `bootstrap()`. Collection is off
/// in debug builds so simulator runs stay out of the dashboards.
class AnalyticsService {
  AnalyticsService(this._analytics);

  factory AnalyticsService.create() {
    final analytics = Firebase.apps.isNotEmpty
        ? FirebaseAnalytics.instance
        : null;
    analytics?.setAnalyticsCollectionEnabled(!kDebugMode);
    return AnalyticsService(analytics);
  }

  final FirebaseAnalytics? _analytics;

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

  /// Tie later events to an account. An internal id only (never PII);
  /// `null` clears it on sign-out.
  Future<void> setUserId(String? id) {
    final analytics = _analytics;
    if (analytics == null) return Future.value();
    return analytics.setUserId(id: id);
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService.create();
});
