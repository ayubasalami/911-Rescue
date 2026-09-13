import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../models/access_analysis.dart';
import '../models/facility.dart';
import '../models/geo_point.dart';
import '../services/access_analysis_service.dart';
import 'facility_repository.dart';

final accessAnalysisRepositoryProvider = Provider<AccessAnalysisRepository>((
  ref,
) {
  return AccessAnalysisRepository(
    ref.watch(accessAnalysisServiceProvider),
    ref.watch(facilityRepositoryProvider),
  );
});

class AccessAnalysisRepository {
  AccessAnalysisRepository(this._service, this._facilityRepository);

  final AccessAnalysisService _service;
  final FacilityRepository _facilityRepository;

  /// Mapbox's Matrix API caps coordinates per request to 10 for
  /// driving-traffic and 25 for other profiles. `/api/hospitals` returns
  /// every Lagos facility (~2,900) with no geographic filter, so this has
  /// to pick a bounded nearest subset itself before ever calling the
  /// Matrix API — sending all of them would just fail the request.
  static const _drivingTrafficMatrixCap = 10;
  static const _otherProfileMatrixCap = 25;

  Future<Result<AccessAnalysisResult>> analyze({
    required GeoPoint origin,
    required TransportMode mode,
    int thresholdMinutes = kAccessAnalysisThresholdMinutes,
  }) async {
    final List<Facility> allFacilities;
    switch (await _facilityRepository.allFacilities()) {
      case Ok(:final value):
        allFacilities = value;
      case Err(:final failure):
        return Err(failure);
    }

    final facilities = _nearestFacilities(
      allFacilities,
      origin: origin,
      limit: mode == TransportMode.driving
          ? _drivingTrafficMatrixCap
          : _otherProfileMatrixCap,
    );
    final destinations = [
      for (final facility in facilities)
        GeoPoint(latitude: facility.latitude, longitude: facility.longitude),
    ];

    final results = await Future.wait([
      _service.fetchIsochrone(origin: origin, mode: mode),
      _service.fetchDurations(
        origin: origin,
        destinations: destinations,
        mode: mode,
      ),
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
        : reachable.fold<int>(
            0,
            (sum, entry) => sum + (entry.facility.catchmentPopulation ?? 0),
          );

    return Ok(
      AccessAnalysisResult(
        mode: mode,
        thresholdMinutes: thresholdMinutes,
        reachableCount: reachable.length,
        population: population,
        closest: closest,
        byBand: byBand,
        isochroneRings: isochroneRings,
      ),
    );
  }

  /// The [limit] facilities closest to [origin] by straight-line distance —
  /// the Matrix API call this feeds only has room for a handful, so this
  /// has to pick which ones are worth asking a real ETA for.
  List<Facility> _nearestFacilities(
    List<Facility> facilities, {
    required GeoPoint origin,
    required int limit,
  }) {
    final sorted = [...facilities]
      ..sort(
        (a, b) =>
            _haversineKm(
              origin,
              GeoPoint(latitude: a.latitude, longitude: a.longitude),
            ).compareTo(
              _haversineKm(
                origin,
                GeoPoint(latitude: b.latitude, longitude: b.longitude),
              ),
            ),
      );
    return sorted.take(limit).toList(growable: false);
  }

  double _haversineKm(GeoPoint a, GeoPoint b) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final h =
        sin(dLat / 2) * sin(dLat / 2) +
        sin(dLng / 2) * sin(dLng / 2) * cos(lat1) * cos(lat2);
    return earthRadiusKm * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  double _degToRad(double deg) => deg * pi / 180;
}
