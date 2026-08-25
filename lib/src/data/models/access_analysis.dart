import 'facility.dart';
import 'geo_point.dart';

/// Matches the web platform's Accessibility Analyzer default threshold.
const kAccessAnalysisThresholdMinutes = 30;

enum TransportMode { driving, walking, motorbike, cycling }

extension TransportModeRouting on TransportMode {
  /// Mapbox has no motorcycle profile, so motorbike reuses driving as the
  /// closest available approximation.
  String get mapboxProfile => switch (this) {
        TransportMode.driving => 'driving-traffic',
        TransportMode.walking => 'walking',
        TransportMode.cycling => 'cycling',
        TransportMode.motorbike => 'driving',
      };

  String get label => switch (this) {
        TransportMode.driving => 'driving',
        TransportMode.walking => 'walking',
        TransportMode.cycling => 'cycling',
        TransportMode.motorbike => 'motorbike',
      };
}

class ReachableFacility {
  const ReachableFacility({
    required this.facility,
    required this.eta,
    required this.straightLineKm,
  });

  final Facility facility;
  final Duration eta;
  final double straightLineKm;
}

class TimeBand {
  const TimeBand(this.maxMinutes, this.label, this.rangeLabel, this.color);

  final int maxMinutes;
  final String label;

  /// e.g. "0-5 mins", matching the web platform's Driving Time legend rows.
  final String rangeLabel;

  /// Matches the web platform's Driving Time legend swatches exactly, so
  /// the legend and the isochrone polygon on the map use identical colors.
  final int color;

  static const bands = [
    TimeBand(5, 'Within 5 mins', '0-5 mins', 0xFF7F1D1D),
    TimeBand(10, 'Within 10 mins', '5-10 mins', 0xFFDC2626),
    TimeBand(15, 'Within 15 mins', '10-15 mins', 0xFFF97316),
    TimeBand(20, 'Within 20 mins', '15-20 mins', 0xFFFB923C),
    TimeBand(25, 'Within 25 mins', '20-25 mins', 0xFFFDBA74),
    TimeBand(30, 'Within 30 mins', '25-30 mins', 0xFFFED7AA),
  ];

  static TimeBand forMinutes(double minutes) {
    for (final band in bands) {
      if (minutes <= band.maxMinutes) return band;
    }
    return bands.last;
  }
}

class IsochroneRing {
  const IsochroneRing({required this.minutes, required this.points});

  final int minutes;
  final List<GeoPoint> points;
}

class DirectionsStep {
  const DirectionsStep({required this.instruction, required this.distanceMeters});

  final String instruction;
  final double distanceMeters;
}

class DirectionsRoute {
  const DirectionsRoute({
    required this.points,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<GeoPoint> points;
  final List<DirectionsStep> steps;
  final double distanceMeters;
  final double durationSeconds;
}

class AccessAnalysisResult {
  const AccessAnalysisResult({
    required this.mode,
    required this.thresholdMinutes,
    required this.reachableCount,
    required this.population,
    required this.closest,
    required this.byBand,
    required this.isochroneRings,
  });

  final TransportMode mode;
  final int thresholdMinutes;
  final int reachableCount;
  final int? population;
  final ReachableFacility? closest;
  final Map<TimeBand, List<ReachableFacility>> byBand;
  final List<IsochroneRing> isochroneRings;
}
