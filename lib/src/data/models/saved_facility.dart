import '../network/json_reader.dart';
import 'facility.dart';

/// A bookmarked facility. The backend keys saves by facility name, so the
/// name is the identity here too.
class SavedFacility {
  const SavedFacility({
    required this.name,
    this.category,
    this.latitude,
    this.longitude,
    this.synced = false,
  });

  factory SavedFacility.fromFacility(Facility facility) => SavedFacility(
    name: facility.name,
    category: facility.rawCategory ?? facility.categoryLabel,
    latitude: facility.latitude,
    longitude: facility.longitude,
  );

  /// An entry of `/api/my_dashboard`'s `saved` list — already on the
  /// server, so [synced].
  factory SavedFacility.fromServer(JsonReader r) => SavedFacility(
    name: r.string('facility_name'),
    category: r.stringOrNull('facility_category'),
    latitude: r.doubleOrNull('facility_lat'),
    longitude: r.doubleOrNull('facility_lng'),
    synced: true,
  );

  factory SavedFacility.fromJson(JsonReader r) => SavedFacility(
    name: r.string('name'),
    category: r.stringOrNull('category'),
    latitude: r.doubleOrNull('lat'),
    longitude: r.doubleOrNull('lng'),
    synced: r.boolOr('synced', fallback: false),
  );

  final String name;

  /// The raw category text the web sends (e.g. "General Hospital").
  final String? category;
  final double? latitude;
  final double? longitude;

  /// Whether the signed-in account already has it.
  final bool synced;

  SavedFacility copyWith({bool? synced}) => SavedFacility(
    name: name,
    category: category,
    latitude: latitude,
    longitude: longitude,
    synced: synced ?? this.synced,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'category': category,
    'lat': latitude,
    'lng': longitude,
    'synced': synced,
  };
}
