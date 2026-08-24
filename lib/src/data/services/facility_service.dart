import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/facility.dart';

final facilityServiceProvider = Provider<FacilityService>((ref) => FacilityService());

class FacilityService {
  // Stub: returns fixture data until the real API exists.
  Future<List<Facility>> fetchNearbyFacilities({
    required double latitude,
    required double longitude,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const [
      Facility(
        id: 'fixture-1',
        name: 'Nigerian Air Force Ikeja Hospital',
        category: FacilityCategory.health,
        address: '12a Adeleke St, Allen, Ikeja, Lagos, Nigeria',
        latitude: 6.5952,
        longitude: 3.3417,
        phone: '0818 906 6902',
      ),
    ];
  }
}
