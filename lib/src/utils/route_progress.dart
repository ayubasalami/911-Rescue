import 'dart:math' as math;

import '../data/models/geo_point.dart';

/// Where a position sits along a route line — the web tracker's `Pp`.
class RouteProgress {
  const RouteProgress({
    required this.segmentIndex,
    required this.foot,
    required this.remainingMeters,
    required this.offByMeters,
  });

  /// The segment (`line[i]`→`line[i + 1]`) the position snaps to.
  final int segmentIndex;

  /// The snapped point on that segment.
  final GeoPoint foot;

  /// Distance left along the line from [foot] to its end.
  final double remainingMeters;

  /// How far the position is from the line.
  final double offByMeters;
}

const _earthRadiusMeters = 6371e3;

double _radians(double degrees) => degrees * math.pi / 180;

/// Great-circle distance, as the web's `Ap`.
double haversineMeters(GeoPoint a, GeoPoint b) {
  final dLat = _radians(b.latitude - a.latitude);
  final dLng = _radians(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_radians(a.latitude)) *
          math.cos(_radians(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(h));
}

/// The compass bearing from [a] to [b] (0° = north, clockwise) — the web's
/// `Ip`, used for heading when the GPS doesn't report one.
double bearingDegrees(GeoPoint a, GeoPoint b) {
  final dLng = _radians(b.longitude - a.longitude);
  final y = math.sin(dLng) * math.cos(_radians(b.latitude));
  final x =
      math.cos(_radians(a.latitude)) * math.sin(_radians(b.latitude)) -
      math.sin(_radians(a.latitude)) *
          math.cos(_radians(b.latitude)) *
          math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// [point] projected onto the segment [a]→[b] on a local flat plane — fine
/// at street scale.
({double distance, GeoPoint foot}) _snapToSegment(
  GeoPoint point,
  GeoPoint a,
  GeoPoint b,
) {
  const metersPerDegree = math.pi / 180 * _earthRadiusMeters;
  final metersPerLngDegree = metersPerDegree * math.cos(_radians(a.latitude));
  final px = (point.longitude - a.longitude) * metersPerLngDegree;
  final py = (point.latitude - a.latitude) * metersPerDegree;
  final sx = (b.longitude - a.longitude) * metersPerLngDegree;
  final sy = (b.latitude - a.latitude) * metersPerDegree;
  final lengthSquared = sx * sx + sy * sy;
  final t = lengthSquared == 0
      ? 0.0
      : ((px * sx + py * sy) / lengthSquared).clamp(0.0, 1.0);
  return (
    distance: math.sqrt(math.pow(px - t * sx, 2) + math.pow(py - t * sy, 2)),
    foot: GeoPoint(
      latitude: a.latitude + t * (b.latitude - a.latitude),
      longitude: a.longitude + t * (b.longitude - a.longitude),
    ),
  );
}

/// The shortest distance from [point] to [line] — the web's off-route test.
double distanceToLine(GeoPoint point, List<GeoPoint> line) {
  if (line.isEmpty) return double.infinity;
  if (line.length == 1) return haversineMeters(point, line.first);
  var best = double.infinity;
  for (var i = 0; i < line.length - 1; i++) {
    best = math.min(best, _snapToSegment(point, line[i], line[i + 1]).distance);
  }
  return best;
}

/// Snaps [point] onto [line], searching [window] segments from [fromIndex]
/// first (progress only moves forward), and the whole line if that's more
/// than 120 m off.
RouteProgress? progressAlong(
  GeoPoint point,
  List<GeoPoint> line, {
  int fromIndex = 0,
  int window = 40,
}) {
  if (line.length < 2) return null;
  final start = fromIndex.clamp(0, line.length - 2);

  ({int index, double distance, GeoPoint foot})? search(int from, int to) {
    ({int index, double distance, GeoPoint foot})? best;
    for (var i = from; i < to; i++) {
      final snap = _snapToSegment(point, line[i], line[i + 1]);
      if (best == null || snap.distance < best.distance) {
        best = (index: i, distance: snap.distance, foot: snap.foot);
      }
    }
    return best;
  }

  var best = search(start, math.min(line.length - 1, start + window));
  if (best == null || best.distance > 120) {
    final wide = search(start, line.length - 1);
    if (wide != null && (best == null || wide.distance < best.distance)) {
      best = wide;
    }
  }
  if (best == null) return null;

  var remaining = haversineMeters(best.foot, line[best.index + 1]);
  for (var i = best.index + 1; i < line.length - 1; i++) {
    remaining += haversineMeters(line[i], line[i + 1]);
  }
  return RouteProgress(
    segmentIndex: best.index,
    foot: best.foot,
    remainingMeters: remaining,
    offByMeters: best.distance,
  );
}
