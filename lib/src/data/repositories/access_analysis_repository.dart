import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_analysis.dart';
import '../models/geo_point.dart';
import '../services/access_analysis_service.dart';
import 'facility_repository.dart';

final accessAnalysisRepositoryProvider = Provider<AccessAnalysisRepository>((ref) {
  return AccessAnalysisRepository(
    ref.watch(accessAnalysisServiceProvider),
    ref.watch(facilityRepositoryProvider),
  );
});

class AccessAnalysisRepository {
  AccessAnalysisRepository(this._service, this._facilityRepository);

  final AccessAnalysisService _service;
  final FacilityRepository _facilityRepository;

  Future<AccessAnalysisResult> analyze({
    required GeoPoint origin,
    required TransportMode mode,
    int thresholdMinutes = kAccessAnalysisThresholdMinutes,
  }) async {
    final facilities = await _facilityRepository.nearbyFacilities(
      latitude: origin.latitude,
      longitude: origin.longitude,
    );
    final destinations = [
      for (final facility in facilities) GeoPoint(latitude: facility.latitude, longitude: facility.longitude),
    ];

    final results = await Future.wait([
      _service.fetchIsochrone(origin: origin, mode: mode),
      _service.fetchDurations(origin: origin, destinations: destinations, mode: mode),
    ]);
    final isochroneRings = results[0] as List<IsochroneRing>;
    final durations = results[1] as List<Duration?>;

    final reachable = <ReachableFacility>[];
    ReachableFacility? closest;
    for (var i = 0; i < facilities.length; i++) {
      final duration = durations[i];
      if (duration == null) continue;
      final facility = facilities[i];
      final entry = ReachableFacility(
        facility: facility,
        eta: duration,
        straightLineKm: _haversineKm(
          origin,
          GeoPoint(latitude: facility.latitude, longitude: facility.longitude),
        ),
      );
      if (closest == null || duration < closest.eta) closest = entry;
      if (duration.inMinutes <= thresholdMinutes) reachable.add(entry);
    }

    final byBand = <TimeBand, List<ReachableFacility>>{};
    for (final entry in reachable) {
      final band = TimeBand.forMinutes(entry.eta.inSeconds / 60);
      byBand.putIfAbsent(band, () => []).add(entry);
    }
    for (final entries in byBand.values) {
      entries.sort((a, b) => a.eta.compareTo(b.eta));
    }

    final population = reachable.isEmpty
        ? null
        : reachable.fold<int>(0, (sum, entry) => sum + (entry.facility.catchmentPopulation ?? 0));

    return AccessAnalysisResult(
      mode: mode,
      thresholdMinutes: thresholdMinutes,
      reachableCount: reachable.length,
      population: population,
      closest: closest,
      byBand: byBand,
      isochroneRings: isochroneRings,
    );
  }

  double _haversineKm(GeoPoint a, GeoPoint b) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final h = sin(dLat / 2) * sin(dLat / 2) + sin(dLng / 2) * sin(dLng / 2) * cos(lat1) * cos(lat2);
    return earthRadiusKm * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  double _degToRad(double deg) => deg * pi / 180;
}
