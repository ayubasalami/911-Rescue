import 'facility.dart';
import 'geo_point.dart';

/// A named point a route can start from or lead to — a known [Facility],
/// a searched place, or the user's live location. Go to Help and the Route
/// Planner both key off this instead of requiring a real [Facility],
/// since the Route Planner's origin/destination can be any searched place,
/// not just one from the facility dataset.
class RoutePoint {
  const RoutePoint({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory RoutePoint.fromFacility(Facility facility) => RoutePoint(
    name: facility.name,
    latitude: facility.latitude,
    longitude: facility.longitude,
  );

  final String name;
  final double latitude;
  final double longitude;

  GeoPoint get point => GeoPoint(latitude: latitude, longitude: longitude);
}
