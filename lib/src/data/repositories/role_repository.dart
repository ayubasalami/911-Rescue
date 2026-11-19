import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who the app is for on this device, chosen on first launch.
enum AppRole { citizen, responder }

final roleRepositoryProvider = Provider<RoleRepository>(
  (ref) => RoleRepository(),
);

/// The citizen/responder choice, on this device only.
class RoleRepository {
  static const _key = 'app_role';

  /// Null until chosen. Never throws: unreadable storage just asks again.
  Future<AppRole?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      return AppRole.values.where((role) => role.name == saved).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AppRole role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, role.name);
    } catch (_) {
      // Worst case the choice is asked for again on the next launch.
    }
  }
}
