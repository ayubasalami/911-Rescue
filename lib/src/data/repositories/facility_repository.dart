import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/facility.dart';
import '../services/facility_service.dart';

final facilityRepositoryProvider = Provider<FacilityRepository>((ref) {
  return FacilityRepository(ref.watch(facilityServiceProvider));
});

class FacilityRepository {
  FacilityRepository(this._service);

  final FacilityService _service;

  Future<List<Facility>> nearbyFacilities({
    required double latitude,
    required double longitude,
  }) {
    return _service.fetchNearbyFacilities(latitude: latitude, longitude: longitude);
  }
}
