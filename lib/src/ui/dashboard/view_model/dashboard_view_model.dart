import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics_events.dart';
import '../../../core/result.dart';
import '../../../data/models/dashboard.dart';
import '../../../data/services/analytics_service.dart';
import '../../../data/services/dashboard_service.dart';
import '../../core/view_model/saved_facilities_view_model.dart';

final dashboardViewModelProvider =
    AsyncNotifierProvider.autoDispose<DashboardViewModel, Dashboard>(
      DashboardViewModel.new,
    );

/// My Dashboard — fetched fresh each time the screen opens.
class DashboardViewModel extends AsyncNotifier<Dashboard> {
  @override
  Future<Dashboard> build() async =>
      switch (await ref.read(dashboardServiceProvider).fetch()) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };

  /// `view`, `navigate` or `remove` — see `AnalyticsEvents.dashboardAction`.
  void logAction(String action) => ref
      .read(analyticsServiceProvider)
      .logEvent(
        AnalyticsEvents.dashboardAction,
        parameters: {'action': action},
      );

  /// Pull to refresh — the current page stays up while it loads.
  Future<void> refresh() async => state = await AsyncValue.guard(build);

  /// The web's Remove: drops the row now, and unsaves on the phone and the
  /// account.
  Future<void> removeSaved(String name) async {
    logAction('remove');
    final current = state.value;
    if (current != null) state = AsyncData(current.withoutSaved(name));
    await ref.read(savedFacilitiesViewModelProvider.notifier).remove(name);
  }
}
