enum FacilityCategory { health, police, fire, roadSafety, other }

class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
  });

  final String id;
  final String name;
  final FacilityCategory category;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
}
