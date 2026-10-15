import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeRepositoryProvider = Provider<ThemeRepository>(
  (ref) => ThemeRepository(),
);

/// The user's light/dark choice, on this device only, under the web's
/// `theme` key (`dark` / `light`). Nothing saved means follow the system.
class ThemeRepository {
  static const _key = 'theme';

  /// Never throws — unreadable storage just means following the system.
  Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return switch (prefs.getString(_key)) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> save(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mode == ThemeMode.system) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
      }
    } catch (_) {
      // Worst case the choice is forgotten on the next launch.
    }
  }
}
