import '../data/models/geo_point.dart';
import 'route_progress.dart';

/// What to do with a responder's GPS fix, by the web console's rules.
enum ShareDecision {
  /// Worse than ±150 m: keep the last good position.
  weak,

  /// First fix, or moved more than 25 m: send now.
  send,

  /// Barely moved: the 20-second heartbeat re-sends it.
  hold,
}

const weakFixMeters = 150.0;
const sendAfterMovingMeters = 25.0;

ShareDecision decideShare({
  required GeoPoint point,
  required double accuracyMeters,
  GeoPoint? lastSent,
}) {
  if (accuracyMeters > weakFixMeters) return ShareDecision.weak;
  if (lastSent == null ||
      haversineMeters(lastSent, point) > sendAfterMovingMeters) {
    return ShareDecision.send;
  }
  return ShareDecision.hold;
}
