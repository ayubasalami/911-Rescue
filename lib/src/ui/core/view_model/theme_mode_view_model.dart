import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics_events.dart';
import '../../../data/repositories/theme_repository.dart';
import '../../../data/services/analytics_service.dart';

/// The saved choice, read in `bootstrap` before the first frame so the app
/// never flashes the wrong theme.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

final themeModeProvider = NotifierProvider<ThemeModeViewModel, ThemeMode>(
  ThemeModeViewModel.new,
);

/// Follows the system until the user toggles; from then on their choice
/// sticks.
class ThemeModeViewModel extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  /// Switches away from what's on screen ([current]) and remembers it.
  void toggle(Brightness current) {
    final next = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
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
