import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';

final compassServiceProvider = Provider<CompassService>(
  (ref) => const CompassService(),
);

/// The phone's compass: the platform's fused heading (gyroscope,
/// magnetometer and accelerometer), which works standing still, unlike the
/// GPS's direction of travel.
class CompassService {
  const CompassService();

  /// Where the top of the phone points, in degrees clockwise from north.
  /// Empty on devices without a compass (and in tests).
  Stream<double> headings() {
    if (isTestEnvironment) return const Stream.empty();
    final events = FlutterCompass.events;
    if (events == null) return const Stream.empty();
    return events
        .map((event) => event.heading)
        .where((heading) => heading != null && heading.isFinite)
        .map((heading) => (heading! % 360 + 360) % 360);
  }
}
