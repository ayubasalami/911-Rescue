import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/facility.dart';
import '../../../data/models/geo_point.dart';
import '../../../data/repositories/facility_repository.dart';
import '../../../data/repositories/location_repository.dart';

const defaultMapCenter = GeoPoint(latitude: 6.5244, longitude: 3.3792);

class HomeMapState {
  const HomeMapState({
    required this.facilities,
    required this.center,
    required this.locationStatus,
  });

  final List<Facility> facilities;
  final GeoPoint center;
  final LocationAccessStatus locationStatus;
}

class HomeMapViewModel extends AsyncNotifier<HomeMapState> {
  @override
  Future<HomeMapState> build() => _load();

  Future<HomeMapState> _load() async {
    final locationResult = await ref.read(locationRepositoryProvider).currentPosition();
    final center = locationResult.position ?? defaultMapCenter;
    final facilities = await ref.read(facilityRepositoryProvider).nearbyFacilities(
          latitude: center.latitude,
          longitude: center.longitude,
        );
    return HomeMapState(
      facilities: facilities,
      center: center,
      locationStatus: locationResult.status,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final homeMapViewModelProvider =
    AsyncNotifierProvider<HomeMapViewModel, HomeMapState>(HomeMapViewModel.new);
