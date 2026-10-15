import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics_events.dart';
import '../../../data/repositories/theme_repository.dart';
import '../../../data/services/analytics_service.dart';

/// The saved choice, read in `bootstrap` before the first frame so the app
/// never flashes the wrong theme.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.light);

final themeModeProvider = NotifierProvider<ThemeModeViewModel, ThemeMode>(
  ThemeModeViewModel.new,
);

/// Light or dark only, as on the web — light until the user toggles, and
/// the phone's own setting never applies.
class ThemeModeViewModel extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  /// Switches to the other theme and remembers it.
  void toggle() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    unawaited(ref.read(themeRepositoryProvider).save(next));
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          AnalyticsEvents.themeToggled,
          parameters: {'theme': next.name},
        );
  }
}
