import '../data/models/access_analysis.dart';
import '../data/models/geo_point.dart';
import 'route_progress.dart';

/// Within this distance a turn is announced — the web's 160 m.
const _announceWithinMeters = 160.0;

/// Closer than this, just the instruction; further, "In N metres, …".
const _immediateMeters = 40.0;

/// An instruction as it should be spoken: whitespace tidied and street
/// abbreviations read out in full, as the web's voice does.
String spokenInstruction(String instruction) => instruction
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'\bRd\b'), 'Road')
    .replaceAll(RegExp(r'\bSt\b'), 'Street')
    .replaceAll(RegExp(r'\bAve\b'), 'Avenue')
    .replaceAll(RegExp(r'\bExpy\b'), 'Expressway')
    .trim();

/// The next turn to announce from [position], or null — the web's rule:
/// the first not-yet-spoken step within 160 m, said once. Marks it and
/// every step before it in [spoken], so passed turns are never read late.
String? nextTurnAnnouncement({
  required List<DirectionsStep> steps,
  required GeoPoint position,
  required Set<int> spoken,
}) {
  for (var i = 0; i < steps.length; i++) {
    if (spoken.contains(i)) continue;
    final location = steps[i].location;
    if (location == null) continue;
    final distance = haversineMeters(position, location);
    if (distance > _announceWithinMeters) continue;
    spoken.addAll([for (var j = 0; j <= i; j++) j]);
    final text = spokenInstruction(steps[i].instruction);
    if (text.isEmpty) return null;
    if (distance <= _immediateMeters) return text;
    final rounded = (distance / 10).round() * 10;
    return 'In $rounded metres, ${text[0].toLowerCase()}${text.substring(1)}';
  }
  return null;
}
