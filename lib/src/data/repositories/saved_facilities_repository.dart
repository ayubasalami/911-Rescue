import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/result.dart';
import '../models/saved_facility.dart';
import '../network/json_reader.dart';
import '../services/saved_facilities_service.dart';

final savedFacilitiesRepositoryProvider = Provider<SavedFacilitiesRepository>(
  (ref) => SavedFacilitiesRepository(ref.watch(savedFacilitiesServiceProvider)),
);

/// Saved facilities live on the phone first — no sign-in needed to save
/// one mid-emergency — and are mirrored to the account when signed in.
///
/// The rule agreed with the backend: the phone's list wins until the
/// account's first sync (every local save is replayed); after that the
/// server's list is authoritative.
class SavedFacilitiesRepository {
  SavedFacilitiesRepository(this._service);

  final SavedFacilitiesService _service;

  static const _key = 'saved_facilities.v1';

  Future<_Store> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return _Store();
      final r = JsonReader(jsonDecode(raw) as Map<String, dynamic>);
      return _Store(
        items: r.list('items', SavedFacility.fromJson).toList(),
        pendingUnsaves: r.stringListOrEmpty('pending_unsaves').toSet(),
        syncedAccount: r.stringOrNull('synced_account'),
      );
    } catch (_) {
      return _Store();
    }
  }

  Future<void> _write(_Store store) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'items': [for (final item in store.items) item.toJson()],
          'pending_unsaves': store.pendingUnsaves.toList(),
          'synced_account': store.syncedAccount,
        }),
      );
    } catch (_) {
      // Worst case the change is lost on the next launch.
    }
  }

  Future<List<SavedFacility>> load() async => (await _read()).items;

  /// Saves on the phone, then to the account when [signedIn]. A failed
  /// upload is retried at the next sync.
  Future<List<SavedFacility>> save(
    SavedFacility facility, {
    required bool signedIn,
  }) async {
    final store = await _read();
    store.items.removeWhere((item) => item.name == facility.name);
    store.pendingUnsaves.remove(facility.name);
    var saved = facility.copyWith(synced: false);
    if (signedIn && (await _service.save(saved)).isOk) {
      saved = saved.copyWith(synced: true);
    }
    store.items.add(saved);
    await _write(store);
    return store.items;
  }

  /// Removes from the phone, and from the account — now when [signedIn],
  /// otherwise at the next sync if the account already had it.
  Future<List<SavedFacility>> unsave(
    String name, {
    required bool signedIn,
  }) async {
    final store = await _read();
    final index = store.items.indexWhere((item) => item.name == name);
    final wasSynced = index != -1 && store.items[index].synced;
    if (index != -1) store.items.removeAt(index);
    if (wasSynced || signedIn) {
      final removed = signedIn && (await _service.unsave(name)).isOk;
      if (!removed) store.pendingUnsaves.add(name);
    }
    await _write(store);
    return store.items;
  }

  /// The account was deleted: keep the phone's saves, but as the phone's
  /// own again — unsynced, with no account and nothing pending to remove.
  Future<List<SavedFacility>> forgetAccount() async {
    final store = await _read();
    store.items = [
      for (final item in store.items) item.copyWith(synced: false),
    ];
    store.pendingUnsaves.clear();
    store.syncedAccount = null;
    await _write(store);
    return store.items;
  }

  /// Brings the phone and [account] in step: replays pending removals and
  /// unsynced saves (every save, on the account's first sync), then takes
  /// the server's list. Saves that failed to upload are kept for next time.
  Future<List<SavedFacility>> sync(String account) async {
    final store = await _read();
    if (store.syncedAccount != account) {
      store.items = [
        for (final item in store.items) item.copyWith(synced: false),
      ];
    }

    for (final name in [...store.pendingUnsaves]) {
      if ((await _service.unsave(name)).isOk) store.pendingUnsaves.remove(name);
    }
    for (final (index, item) in store.items.indexed) {
      if (!item.synced && (await _service.save(item)).isOk) {
        store.items[index] = item.copyWith(synced: true);
      }
    }

    if (await _service.fetchSaved() case Ok(value: final server)) {
      final serverNames = {for (final item in server) item.name};
      store.items = [
        ...server,
        for (final item in store.items)
          if (!item.synced && !serverNames.contains(item.name)) item,
      ];
      store.syncedAccount = account;
    }
    await _write(store);
    return store.items;
  }
}

class _Store {
  _Store({
    List<SavedFacility>? items,
    Set<String>? pendingUnsaves,
    this.syncedAccount,
  }) : items = items ?? [],
       pendingUnsaves = pendingUnsaves ?? {};

  List<SavedFacility> items;
  final Set<String> pendingUnsaves;

  /// The account whose first sync has happened — the server is the
  /// authority for it from then on.
  String? syncedAccount;
}
