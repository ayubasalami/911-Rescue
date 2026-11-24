import 'dart:async' show TimeoutException;

import '../services/analytics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/geo_point.dart';
import '../services/location_service.dart';

enum LocationAccessStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  timedOut,
}

class LocationResult {
  const LocationResult.granted(GeoPoint point, {this.accuracy})
    : status = LocationAccessStatus.granted,
      position = point;

  const LocationResult.unavailable(this.status)
    : position = null,
      accuracy = null;

  final LocationAccessStatus status;
  final GeoPoint? position;

  /// GPS accuracy in metres, when [position] came from a real fix —
  /// required by `POST /api/ping` ("accuracy is not decoration... a 200m
  /// fix drawn as precise is actively misleading").
  final double? accuracy;
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(
    ref.watch(locationServiceProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
});

class LocationRepository {
  LocationRepository(this._service, {this._analytics});

  final LocationService _service;
  final AnalyticsService? _analytics;

  /// Every lookup counts toward the dashboard's GPS success rate.
  Future<LocationResult> currentPosition() async {
    final result = await _locate();
    if (result.position != null) {
      _analytics?.track('gps_success');
    } else {
      _analytics?.track('gps_fail', {
        'reason': switch (result.status) {
          LocationAccessStatus.timedOut => 'timeout',
          LocationAccessStatus.serviceDisabled => 'unavailable',
          _ => 'denied',
        },
      });
    }
    return result;
  }

  Future<LocationResult> _locate() async {
    if (!await _service.isLocationServiceEnabled()) {
      return const LocationResult.unavailable(
        LocationAccessStatus.serviceDisabled,
      );
    }

    var permission = await _service.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _service.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult.unavailable(LocationAccessStatus.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.unavailable(
        LocationAccessStatus.deniedForever,
      );
    }

    try {
      final position = await _service.getCurrentPosition();
      return LocationResult.granted(
        GeoPoint(latitude: position.latitude, longitude: position.longitude),
        accuracy: position.accuracy,
      );
    } on TimeoutException {
      return const LocationResult.unavailable(LocationAccessStatus.timedOut);
    }
  }

  /// Live GPS fixes for Go to Help's "Start" tracking. Yields nothing if
  /// location access isn't available — the caller just never gets updates,
  /// same as [currentPosition] returning a null position.
  Stream<TrackedPosition> positionStream() async* {
    if (!await _service.isLocationServiceEnabled()) return;

    var permission = await _service.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _service.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    yield* _service.positionStream().map(
      (position) => TrackedPosition(
        point: GeoPoint(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
        accuracyMeters: position.accuracy,
        // Platforms report -1 (or a stale value) when not moving.
        headingDegrees: position.heading >= 0 && position.speed > 0.5
            ? position.heading
            : null,
        speedMps: position.speed >= 0 ? position.speed : null,
      ),
    );
  }
}
