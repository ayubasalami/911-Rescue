import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../models/facility.dart';
import '../models/geo_point.dart';
import '../services/facility_service.dart';

final facilityRepositoryProvider = Provider<FacilityRepository>((ref) {
  return FacilityRepository(ref.watch(facilityServiceProvider));
});

class FacilityRepository {
  FacilityRepository(this._service);

  final FacilityService _service;

  /// Every Lagos facility — `/api/hospitals` has no geographic filter and
  /// always returns the full set (~2,900), so a caller that wants only
  /// nearby ones filters the result itself (see
  /// `AccessAnalysisRepository.analyze`, which has to for a different
  /// reason: the Matrix API's own coordinate cap).
  Future<Result<List<Facility>>> allFacilities({bool forceRefresh = false}) {
    return _service.fetchAllFacilities(forceRefresh: forceRefresh);
  }

  Future<Result<List<Facility>>> search(String query) =>
      _service.searchFacilities(query);

  Future<Result<Facility>> nearest(GeoPoint point) =>
      _service.nearestFacility(point);

  Future<Result<List<GeoPoint>>> boundary() => _service.fetchBoundary();
}
