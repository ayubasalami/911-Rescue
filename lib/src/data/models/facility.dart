enum FacilityCategory { health, police, fire, roadSafety, other }

extension FacilityCategoryLabel on FacilityCategory {
  String get displayLabel => switch (this) {
    FacilityCategory.health => 'Health Facility',
    FacilityCategory.police => 'Police',
    FacilityCategory.fire => 'Fire & Emergency',
    FacilityCategory.roadSafety => 'Road Safety',
    FacilityCategory.other => 'Other',
  };
}

class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
  });

  final String id;
  final String name;
  final FacilityCategory category;
  final double latitude;
  final double longitude;

  /// Null for a facility that came from `/api/search_facilities` or
  /// `/api/nearest_hospital` — those only return name/category/coordinates,
  /// not an address (see `FacilityService`).
  final String? address;
  final String? phone;
}
