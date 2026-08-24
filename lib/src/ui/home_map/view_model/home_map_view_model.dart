import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/facility.dart';
import '../../../data/repositories/facility_repository.dart';

class HomeMapViewModel extends AsyncNotifier<List<Facility>> {
  @override
  Future<List<Facility>> build() {
    return _loadFacilities();
  }

  Future<List<Facility>> _loadFacilities() {
    // Placeholder coordinates until real device geolocation is wired in.
    return ref.read(facilityRepositoryProvider).nearbyFacilities(
          latitude: 6.5244,
          longitude: 3.3792,
        );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadFacilities);
  }
}

final homeMapViewModelProvider =
    AsyncNotifierProvider<HomeMapViewModel, List<Facility>>(HomeMapViewModel.new);
