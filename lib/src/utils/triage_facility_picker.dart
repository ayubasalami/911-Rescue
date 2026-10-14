import 'package:geolocator/geolocator.dart';

import '../data/models/facility.dart';
import '../data/models/geo_point.dart';

/// Picks where a Triage result sends the user — a straight port of the web
/// platform's choice (911rescueme.com), so both clients route the same
/// report to the same place:
///
/// 1. A health **emergency** goes to an emergency-capable facility (clinic
///    tier or above — never a pharmacy, lab, dental/eye clinic or health
///    post), preferring bigger hospitals unless they're much further away.
/// 2. Otherwise the nearest facility of [category] — for health, narrowed
///    to [department] when Triage named one.
/// 3. Failing that, the nearest of [category]; failing that, the nearest of
///    anything.
Facility? pickTriageFacility({
  required List<Facility> facilities,
  required GeoPoint origin,
  required FacilityCategory category,
  String? department,
  required bool isEmergency,
}) {
  double distanceTo(Facility f) => Geolocator.distanceBetween(
    origin.latitude,
    origin.longitude,
    f.latitude,
    f.longitude,
  );

  Facility? nearestWhere(bool Function(Facility) test) {
    Facility? best;
    var bestDistance = double.infinity;
    for (final f in facilities) {
      if (!test(f)) continue;
      final d = distanceTo(f);
      if (d < bestDistance) {
        best = f;
        bestDistance = d;
      }
    }
    return best;
  }

  if (isEmergency && category == FacilityCategory.health) {
    final candidates = [
      for (final f in facilities)
        if (f.category == FacilityCategory.health && _tier(f) >= _Tier.clinic)
          (facility: f, distance: distanceTo(f), tier: _tier(f)),
    ];
    if (candidates.isNotEmpty) {
      final closest = candidates
          .map((c) => c.distance)
          .reduce((a, b) => a < b ? a : b);
      Facility? best;
      var bestScore = double.infinity;
      for (final c in candidates) {
        final score = _emergencyScore(c.distance, c.tier, closest);
        if (score < bestScore) {
          best = c.facility;
          bestScore = score;
        }
      }
      if (best != null) return best;
    }
  }

  return nearestWhere(
        (f) =>
            f.category == category &&
            (category != FacilityCategory.health ||
                department == null ||
                _matchesDepartment(f, department)),
      ) ??
      nearestWhere((f) => f.category == category) ??
      nearestWhere((_) => true);
}

/// The web's general-care departments: Triage naming any of them accepts a
/// facility of any of them, rather than only an exact match.
const _generalDepartments = [
  'primary health center',
  'primary health clinic',
  'general hospital',
  'teaching/tertiary hospital',
  'health post',
];

bool _matchesDepartment(Facility facility, String department) {
  final dept = department.toLowerCase();
  final raw = (facility.rawCategory ?? '').toLowerCase();
  if (_generalDepartments.contains(dept)) {
    return _generalDepartments.any(raw.contains);
  }
  return raw.contains(dept) || dept.contains(raw);
}

/// Ranks of facility, highest first — the web's tiers and values.
abstract final class _Tier {
  static const tertiary = 5;
  static const general = 4;
  static const clinic = 3;
  static const maternity = 3;
  static const post = 2;
  static const minor = 1;
  static const unknown = 2;
}

const _tierKeywords = [
  (
    tier: _Tier.tertiary,
    match: [
      'teaching',
      'tertiary',
      'federal medical',
      'specialist hospital',
      'university teaching',
    ],
  ),
  (
    tier: _Tier.general,
    match: [
      'general hospital',
      'hospital',
      'medical cent',
      'medical center',
      'medical centre',
    ],
  ),
  (tier: _Tier.maternity, match: ['maternity', 'obstetric']),
  (tier: _Tier.post, match: ['health post', 'dispensary']),
  (
    tier: _Tier.clinic,
    match: ['primary health', 'health cent', 'clinic', 'medical practice'],
  ),
];

const _minorKeywords = [
  'pharmacy',
  'chemist',
  'laboratory',
  'diagnostic',
  'dental',
  'eye clinic',
  'optical',
  'physiotherapy',
  'radiology',
];

int _tier(Facility facility) {
  final text = '${facility.rawCategory ?? ''} ${facility.name}'.toLowerCase();
  if (_minorKeywords.any(text.contains)) {
    return text.contains('hospital') ? _Tier.general : _Tier.minor;
  }
  for (final entry in _tierKeywords) {
    if (entry.match.any(text.contains)) return entry.tier;
  }
  return _Tier.unknown;
}

/// Distance discounted by how capable the facility is, so a big hospital
/// can win over a nearer clinic — but nothing more than 2.2× the closest
/// candidate's distance is considered at all. Maternity and clinic share a
/// rank, so they share a weight (the web's lookup collapses them too).
double _emergencyScore(double distance, int tier, double closest) {
  if (distance > closest * 2.2) return double.infinity;
  final weight = switch (tier) {
    _Tier.tertiary => 3.0,
    _Tier.general => 2.6,
    _Tier.clinic => 1.0,
    _ => 0.5,
  };
  return distance / weight;
}
