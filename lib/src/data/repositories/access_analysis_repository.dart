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

  /// Mapbox's Matrix API caps *total* coordinates per request — origin
  /// included — to 10 for driving-traffic and 25 for other profiles.
  /// `/api/hospitals` returns every Lagos facility (~2,900) with no
  /// geographic filter, so this has to pick a bounded nearest subset
  /// itself before ever calling the Matrix API — sending all of them
  /// would just fail the request.
  ///
  /// Confirmed live: using these numbers directly as the *destination*
  /// limit and then prepending the origin on top (see
  /// `AccessAnalysisService.fetchDurations`) pushed driving-traffic to 11
  /// total coordinates and got a real 422 back ("maximum number of
  /// coordinates is 10") — Analyze Access failed every time as a result.
  /// Both limits are one less than Mapbox's own cap, to leave room for
  /// the origin as coordinate 0.
  static const _drivingTrafficMatrixCap = 10 - 1;
  static const _otherProfileMatrixCap = 25 - 1;

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

    final (isochroneResult, durationsResult) = await (
      _service.fetchIsochrone(origin: origin, mode: mode),
      _service.fetchDurations(
        origin: origin,
        destinations: destinations,
        mode: mode,
      ),
    ).wait;

    final List<IsochroneRing> isochroneRings;
    switch (isochroneResult) {
      case Ok(:final value):
        isochroneRings = value;
      case Err(:final failure):
        return Err(failure);
    }

    final List<Duration?> durations;
    switch (durationsResult) {
      case Ok(:final value):
        durations = value;
      case Err(:final failure):
        return Err(failure);
    }

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

    // Real reachable-population data from the backend's isochrones (no
    // facility carries a real census figure of its own) — the band with
    // the largest `minutes` that still fits within [thresholdMinutes],
    // i.e. the closest coverage to what was actually asked for without
    // exceeding it.
    final population = isochroneRings
        .where((ring) => ring.minutes <= thresholdMinutes)
        .fold<IsochroneRing?>(
          null,
          (best, ring) =>
              best == null || ring.minutes > best.minutes ? ring : best,
        )
        ?.population;

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
