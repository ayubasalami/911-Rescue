import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/facility.dart';
import '../../../data/models/saved_facility.dart';
import '../../../data/repositories/saved_facilities_repository.dart';
import 'auth_view_model.dart';

final savedFacilitiesViewModelProvider =
    AsyncNotifierProvider<SavedFacilitiesViewModel, List<SavedFacility>>(
      SavedFacilitiesViewModel.new,
    );

/// The phone's saved facilities, synced with the account whenever someone
/// signs in (including a session restored at launch).
class SavedFacilitiesViewModel extends AsyncNotifier<List<SavedFacility>> {
  SavedFacilitiesRepository get _repository =>
      ref.read(savedFacilitiesRepositoryProvider);

  @override
  Future<List<SavedFacility>> build() async {
    ref.listen(authViewModelProvider, (previous, next) {
      final email = next.value?.email;
      if (email != null && email != previous?.value?.email) {
        // After build has finished, so the sync's result isn't overwritten
        // by the local list build returns.
        scheduleMicrotask(() => _sync(email));
      }
    }, fireImmediately: true);
    return _repository.load();
  }

  Future<void> _sync(String email) async {
    await future;
    state = AsyncData(await _repository.sync(email));
  }

  bool isSaved(Facility facility) =>
      state.value?.any((item) => item.name == facility.name) ?? false;

  /// Unsaves by name — the dashboard's Remove, which has no [Facility].
  Future<void> remove(String name) async {
    final signedIn = ref.read(authViewModelProvider).value != null;
    final current = state.value ?? const <SavedFacility>[];
    state = AsyncData([
      for (final item in current)
        if (item.name != name) item,
    ]);
    state = AsyncData(await _repository.unsave(name, signedIn: signedIn));
  }

  /// Saves or unsaves [facility]; returns whether it's now saved.
  Future<bool> toggle(Facility facility) async {
    final signedIn = ref.read(authViewModelProvider).value != null;
    final saving = !isSaved(facility);
    final current = state.value ?? const <SavedFacility>[];
    // Flip the button now; the upload can take a moment.
    state = AsyncData([
      for (final item in current)
        if (item.name != facility.name) item,
      if (saving) SavedFacility.fromFacility(facility),
    ]);
    state = AsyncData(
      saving
          ? await _repository.save(
              SavedFacility.fromFacility(facility),
              signedIn: signedIn,
            )
          : await _repository.unsave(facility.name, signedIn: signedIn),
    );
    return saving;
  }
}
