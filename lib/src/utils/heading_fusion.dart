/// Which way the user is facing during navigation, as map apps decide it:
/// the GPS's direction of travel at driving speed, where it's reliable and
/// the compass isn't (a car's metal and a mounted phone throw it off), and
/// the phone's compass when slow or standing still, where GPS has none.
class HeadingFusion {
  HeadingFusion({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  /// About 11 km/h: below this the GPS direction wanders.
  static const gpsMinSpeedMps = 3.0;

  /// A GPS direction older than this gives way to the compass again.
  static const gpsFreshFor = Duration(seconds: 4);

  /// Smaller turns aren't passed on, so the cone and map don't jitter.
  static const minChangeDegrees = 3.0;

  final DateTime Function() _now;
  double? _gps;
  DateTime? _gpsAt;
  double? _compass;
  double? _shown;

  /// The heading to show now, or null if neither source has one.
  double? get current {
    final gpsAt = _gpsAt;
    if (_gps != null &&
        gpsAt != null &&
        _now().difference(gpsAt) < gpsFreshFor) {
      return _gps;
    }
    return _compass;
  }

  /// A GPS fix; returns the heading to show if it changed enough.
  double? onGps(double? course, double? speedMps) {
    if (course != null && speedMps != null && speedMps >= gpsMinSpeedMps) {
      _gps = course;
      _gpsAt = _now();
    } else {
      _gps = null;
      _gpsAt = null;
    }
    return _emit();
  }

  /// A compass reading; returns the heading to show if it changed enough.
  double? onCompass(double heading) {
    _compass = heading;
    return _emit();
  }

  double? _emit() {
    final next = current;
    if (next == null) return null;
    final shown = _shown;
    if (shown != null && _gap(shown, next) < minChangeDegrees) {
      return null;
    }
    _shown = next;
    return next;
  }
}

/// The angle between two bearings, 0–180°.
double _gap(double a, double b) => ((a - b + 540) % 360 - 180).abs();
