import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeRepositoryProvider = Provider<ThemeRepository>(
  (ref) => ThemeRepository(),
);

/// The user's light/dark choice, on this device only, under the web's
/// `theme` key (`dark` / `light`). Like the web, nothing saved means light —
/// the system setting is ignored.
class ThemeRepository {
  static const _key = 'theme';

  /// Never throws — unreadable storage just means light.
  Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key) == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      return ThemeMode.light;
    }
  }

  Future<void> save(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {
      // Worst case the choice is forgotten on the next launch.
    }
  }
}
