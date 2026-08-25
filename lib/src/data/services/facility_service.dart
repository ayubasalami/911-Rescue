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
        catchmentPopulation: 82000,
      ),
      Facility(
        id: 'fixture-2',
        name: 'Lagos Island Maternity Hospital',
        category: FacilityCategory.health,
        address: 'Odunlami St, Lagos Island, Lagos, Nigeria',
        latitude: 6.4541,
        longitude: 3.3947,
        catchmentPopulation: 65000,
      ),
      Facility(
        id: 'fixture-3',
        name: 'Marina Police Division',
        category: FacilityCategory.police,
        address: 'Marina, Lagos Island, Lagos, Nigeria',
        latitude: 6.4531,
        longitude: 3.3958,
        catchmentPopulation: 40000,
      ),
      Facility(
        id: 'fixture-4',
        name: 'Lagos State Fire Service — Alausa Station',
        category: FacilityCategory.fire,
        address: 'Alausa, Ikeja, Lagos, Nigeria',
        latitude: 6.6018,
        longitude: 3.3515,
        catchmentPopulation: 120000,
      ),
      Facility(
        id: 'fixture-5',
        name: 'FRSC Command Office, Ikeja',
        category: FacilityCategory.roadSafety,
        address: 'Oba Akran Ave, Ikeja, Lagos, Nigeria',
        latitude: 6.5833,
        longitude: 3.3500,
        catchmentPopulation: 95000,
      ),
      Facility(
        id: 'fixture-6',
        name: 'Lekki Phase 1 Police Post',
        category: FacilityCategory.police,
        address: 'Admiralty Way, Lekki Phase 1, Lagos, Nigeria',
        latitude: 6.4432,
        longitude: 3.4732,
        catchmentPopulation: 54000,
      ),
      Facility(
        id: 'fixture-7',
        name: 'Yaba Police Division',
        category: FacilityCategory.police,
        address: 'Herbert Macaulay Way, Yaba, Lagos, Nigeria',
        latitude: 6.5000,
        longitude: 3.3833,
        catchmentPopulation: 47000,
      ),
      Facility(
        id: 'fixture-8',
        name: 'Reddington Hospital, Victoria Island',
        category: FacilityCategory.health,
        address: 'Idowu Martins St, Victoria Island, Lagos, Nigeria',
        latitude: 6.4300,
        longitude: 3.4200,
        catchmentPopulation: 38000,
      ),
    ];
  }
}
