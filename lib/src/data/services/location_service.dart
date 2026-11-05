import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/env.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

class LocationService {
  // geolocator's platform channel isn't mocked under flutter_test and hangs
  // indefinitely, so fall back to a canned Lagos position there.
  bool get _isTestEnvironment => isTestEnvironment;

  Future<bool> isLocationServiceEnabled() => _isTestEnvironment
      ? Future.value(true)
      : Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => _isTestEnvironment
      ? Future.value(LocationPermission.whileInUse)
      : Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() => _isTestEnvironment
      ? Future.value(LocationPermission.whileInUse)
      : Geolocator.requestPermission();

  Future<Position> getCurrentPosition() {
    if (_isTestEnvironment) {
      return Future.value(
        Position(
          latitude: 6.5244,
          longitude: 3.3792,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// Live GPS updates for Go to Help's "Start" tracking. No distance filter,
  /// like the web's `watchPosition`: on Android one can hold back even the
  /// first fix until the user has moved, leaving no "You are here" marker.
  Stream<Position> positionStream() {
    if (_isTestEnvironment) {
      return Stream.value(
        Position(
          latitude: 6.5244,
          longitude: 3.3792,
          timestamp: DateTime.now(),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
    }
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
