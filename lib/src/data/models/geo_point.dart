class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// A single fix from the live GPS stream, used while a Go to Help route is
/// being tracked — [accuracyMeters] drives the "Weak/Good GPS signal"
/// indicator, matching the web platform's live navigation card.
class TrackedPosition {
  const TrackedPosition({required this.point, required this.accuracyMeters});

  final GeoPoint point;
  final double accuracyMeters;
}
