import 'dart:async' show TimeoutException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/geo_point.dart';
import '../services/location_service.dart';

enum LocationAccessStatus { granted, denied, deniedForever, serviceDisabled, timedOut }

class LocationResult {
  const LocationResult.granted(GeoPoint point)
      : status = LocationAccessStatus.granted,
        position = point;

  const LocationResult.unavailable(this.status) : position = null;

  final LocationAccessStatus status;
  final GeoPoint? position;
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(ref.watch(locationServiceProvider));
});

class LocationRepository {
  LocationRepository(this._service);

  final LocationService _service;

  Future<LocationResult> currentPosition() async {
    if (!await _service.isLocationServiceEnabled()) {
      return const LocationResult.unavailable(LocationAccessStatus.serviceDisabled);
    }

    var permission = await _service.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _service.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult.unavailable(LocationAccessStatus.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.unavailable(LocationAccessStatus.deniedForever);
    }

    try {
      final position = await _service.getCurrentPosition();
      return LocationResult.granted(GeoPoint(latitude: position.latitude, longitude: position.longitude));
    } on TimeoutException {
      return const LocationResult.unavailable(LocationAccessStatus.timedOut);
    }
  }
}
