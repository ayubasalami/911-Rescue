import 'facility.dart';
import 'geo_point.dart';

/// Matches the web platform's Accessibility Analyzer default threshold.
const kAccessAnalysisThresholdMinutes = 30;

enum TransportMode { driving, walking, motorbike, cycling }

extension TransportModeRouting on TransportMode {
  /// Mapbox has no motorcycle profile, so motorbike reuses driving as the
  /// closest available approximation. Only used by [AccessAnalysisService]'s
  /// still-direct-to-Mapbox Matrix API calls now — /api/directions and
  /// /api/isochrones use [backendMode] instead.
  String get mapboxProfile => switch (this) {
    TransportMode.driving => 'driving-traffic',
    TransportMode.walking => 'walking',
    TransportMode.cycling => 'cycling',
    TransportMode.motorbike => 'driving',
  };

  /// The 911 Rescue backend's `mode` query parameter for /api/directions
  /// and /api/isochrones. Distinct from [mapboxProfile]: the backend has a
  /// real motorcycle profile ("biking"), and — per the API docs, called
  /// out explicitly as an easy mistake — "biking" means motorcycle/okada
  /// while "cycling" means a pedal bicycle, the opposite of what the names
  /// might suggest at a glance.
  String get backendMode => switch (this) {
    TransportMode.driving => 'driving',
    TransportMode.walking => 'walking',
    TransportMode.cycling => 'cycling',
    TransportMode.motorbike => 'biking',
  };

  String get label => switch (this) {
    TransportMode.driving => 'driving',
    TransportMode.walking => 'walking',
    TransportMode.cycling => 'cycling',
    TransportMode.motorbike => 'motorbike',
  };

  /// The legend heading — the web's "{Mode} Time", with motorcycle shown
  /// as "Motorcycling".
  String get timeLegendTitle => switch (this) {
    TransportMode.driving => 'Driving Time',
    TransportMode.walking => 'Walking Time',
    TransportMode.cycling => 'Cycling Time',
    TransportMode.motorbike => 'Motorcycling Time',
  };

  /// The colour of the [minutes] time band for this mode — the web's
  /// per-mode palettes (reds, greens, purples, blues), darkest nearest. A
  /// band between the palette's 5-minute steps takes the nearest step.
  int bandColor(int minutes) {
    final palette = _bandPalettes[this]!;
    var nearest = palette.keys.first;
    for (final step in palette.keys) {
      if ((step - minutes).abs() < (nearest - minutes).abs()) nearest = step;
    }
    return palette[nearest]!;
  }
}

const _bandPalettes = {
  TransportMode.driving: {
    5: 0xFFA50F15,
    10: 0xFFDE2D26,
    15: 0xFFFB6A4A,
    20: 0xFFFCA082,
    25: 0xFFFCC5C0,
    30: 0xFFFEE5D9,
  },
  TransportMode.walking: {
    5: 0xFF005A32,
    10: 0xFF238B45,
    15: 0xFF41AB5D,
    20: 0xFF74C476,
    25: 0xFFA1D99B,
    30: 0xFFC7E9C0,
  },
  TransportMode.motorbike: {
    5: 0xFF4A1486,
    10: 0xFF6A51A3,
    15: 0xFF807DBA,
    20: 0xFF9E9AC8,
    25: 0xFFBCBDDC,
    30: 0xFFDADAEB,
  },
  TransportMode.cycling: {
    5: 0xFF084594,
    10: 0xFF2171B5,
    15: 0xFF4292C6,
    20: 0xFF6BAED6,
    25: 0xFF9ECAE1,
    30: 0xFFC6DBEF,
  },
};

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
  const TimeBand(this.maxMinutes, this.label, this.rangeLabel);

  final int maxMinutes;
  final String label;

  /// e.g. "0-5 mins", matching the web platform's time legend rows. Colours
  /// depend on the travel mode — see [TransportModeRouting.bandColor].
  final String rangeLabel;

  static const bands = [
    TimeBand(5, 'Within 5 mins', '0-5 mins'),
    TimeBand(10, 'Within 10 mins', '5-10 mins'),
    TimeBand(15, 'Within 15 mins', '10-15 mins'),
    TimeBand(20, 'Within 20 mins', '15-20 mins'),
    TimeBand(25, 'Within 25 mins', '20-25 mins'),
    TimeBand(30, 'Within 30 mins', '25-30 mins'),
  ];

  static TimeBand forMinutes(double minutes) {
    for (final band in bands) {
      if (minutes <= band.maxMinutes) return band;
    }
    return bands.last;
  }
}

class IsochroneRing {
  const IsochroneRing({
    required this.minutes,
    required this.points,
    this.population,
  });

  final int minutes;
  final List<GeoPoint> points;

  /// Reachable population within this ring, from `/api/isochrones`'
  /// `properties.population` — null when the backend reports "N/A" (seen
  /// live for the smaller bands, presumably below its data's resolution).
  final int? population;
}

class DirectionsStep {
  const DirectionsStep({
    required this.instruction,
    required this.distanceMeters,
    this.location,
  });

  final String instruction;
  final double distanceMeters;

  /// Where the manoeuvre happens — what voice prompts measure to.
  final GeoPoint? location;
}

class DirectionsRoute {
  const DirectionsRoute({
    required this.points,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
    this.source,
    this.fetchedAt,
  });

  final List<GeoPoint> points;
  final List<DirectionsStep> steps;
  final double distanceMeters;
  final double durationSeconds;

  /// `mapbox` or `osrm`. Per the API docs only Mapbox durations account for
  /// live traffic, so only those may be presented as traffic-aware.
  final String? source;

  bool get hasLiveTraffic => source == 'mapbox';

  /// When the route came back — the arrival time is fixed from here, as
  /// on the web, rather than drifting later on every redraw.
  final DateTime? fetchedAt;
}

extension DirectionsRouteFormatting on DirectionsRoute {
  String get formattedDistance =>
      '${(distanceMeters / 1000).toStringAsFixed(1)} km';

  String get formattedDuration {
    final totalMinutes = (durationSeconds / 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return hours > 0 ? '$hours hr $minutes min' : '$minutes min';
  }

  /// A clock-formatted ETA from when the route was fetched — the web
  /// platform shows this alongside the route summary (e.g. "Arrive 05:40
  /// AM").
  String get formattedArrival {
    final arrival = (fetchedAt ?? DateTime.now()).add(
      Duration(seconds: durationSeconds.round()),
    );
    final hour12 = arrival.hour % 12 == 0 ? 12 : arrival.hour % 12;
    final minute = arrival.minute.toString().padLeft(2, '0');
    final period = arrival.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }
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
