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
    this.rawCategory,
    this.description,
    this.website,
    this.imageUrl,
    this.services = const [],
  });

  /// A general place from the OpenStreetMap search, opened in the same
  /// popup as a facility — the web does exactly this, labelled "Location".
  factory Facility.place({
    required String name,
    required double latitude,
    required double longitude,
  }) => Facility(
    id: '$_placeIdPrefix$name@$latitude,$longitude',
    name: name,
    category: FacilityCategory.other,
    rawCategory: 'Location',
    latitude: latitude,
    longitude: longitude,
  );

  static const _placeIdPrefix = 'place:';

  /// A searched place, not one of the backend's facilities — it has no map
  /// marker of its own.
  bool get isPlace => id.startsWith(_placeIdPrefix);

  /// What the popup, info sheet and search list show under the name.
  String get categoryLabel => isPlace ? 'Location' : category.displayLabel;

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

  /// The backend's own free-text category (e.g. "General Hospital",
  /// "Pharmacy") before it's grouped into [category] — what Triage uses to
  /// match a department and to rank hospitals for an emergency.
  final String? rawCategory;

  /// Only on facilities from `/api/hospitals` — View Info falls back to
  /// per-category defaults (as the web does) when these are missing.
  final String? description;
  final String? website;

  /// A photo URL; may be relative to the API host (see View Info).
  final String? imageUrl;
  final List<String> services;
}
