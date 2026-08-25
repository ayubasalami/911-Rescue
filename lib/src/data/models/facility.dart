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
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.catchmentPopulation,
  });

  final String id;
  final String name;
  final FacilityCategory category;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;

  /// Mock estimate of the population served by this facility, used for the
  /// Accessibility Analyzer's POPULATION stat until a real census dataset
  /// is available from the backend.
  final int? catchmentPopulation;
}
