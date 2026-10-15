class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// A single fix from the live GPS stream, used while a Go to Help route is
/// being tracked — [accuracyMeters] drives the "Weak/Good GPS signal"
/// indicator, matching the web platform's live navigation card.
class TrackedPosition {
  const TrackedPosition({
    required this.point,
    required this.accuracyMeters,
    this.headingDegrees,
  });

  final GeoPoint point;
  final double accuracyMeters;

  /// The GPS's direction of travel (0° = north, clockwise), or null when
  /// standing still or unknown.
  final double? headingDegrees;
}
