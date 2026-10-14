import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/data/models/facility.dart';
import 'package:rescue_911/src/data/models/geo_point.dart';
import 'package:rescue_911/src/utils/triage_facility_picker.dart';

const _origin = GeoPoint(latitude: 6.5, longitude: 3.3);

/// A facility [km] kilometres north of [_origin].
Facility _at(
  double km,
  String name, {
  String? rawCategory,
  FacilityCategory category = FacilityCategory.health,
}) => Facility(
  id: name,
  name: name,
  category: category,
  rawCategory: rawCategory,
  latitude: _origin.latitude + km / 111.0,
  longitude: _origin.longitude,
);

void main() {
  test('a health emergency skips pharmacies and labs', () {
    final picked = pickTriageFacility(
      facilities: [
        _at(0.2, 'Corner Pharmacy', rawCategory: 'Pharmacy'),
        _at(0.3, 'City Lab', rawCategory: 'Medical Laboratory'),
        _at(1.0, 'Ward Clinic', rawCategory: 'Primary Health Center'),
      ],
      origin: _origin,
      category: FacilityCategory.health,
      isEmergency: true,
    );
    expect(picked?.name, 'Ward Clinic');
  });

  test('a health emergency prefers a hospital within 2.2x the distance', () {
    final picked = pickTriageFacility(
      facilities: [
        _at(1.0, 'Ward Clinic', rawCategory: 'Primary Health Center'),
        _at(2.0, 'Lagos General', rawCategory: 'General Hospital'),
      ],
      origin: _origin,
      category: FacilityCategory.health,
      isEmergency: true,
    );
    expect(picked?.name, 'Lagos General');
  });

  test('a hospital beyond 2.2x the closest is not considered', () {
    final picked = pickTriageFacility(
      facilities: [
        _at(1.0, 'Ward Clinic', rawCategory: 'Primary Health Center'),
        _at(3.0, 'Lagos General', rawCategory: 'General Hospital'),
      ],
      origin: _origin,
      category: FacilityCategory.health,
      isEmergency: true,
    );
    expect(picked?.name, 'Ward Clinic');
  });

  test('a non-emergency department narrows to matching facilities', () {
    final picked = pickTriageFacility(
      facilities: [
        _at(0.5, 'Ward Clinic', rawCategory: 'Primary Health Center'),
        _at(2.0, 'Smile Dental', rawCategory: 'Dental Clinic'),
      ],
      origin: _origin,
      category: FacilityCategory.health,
      department: 'Dental Clinic',
      isEmergency: false,
    );
    expect(picked?.name, 'Smile Dental');
  });

  test('other agencies take the nearest of their category', () {
    final picked = pickTriageFacility(
      facilities: [
        _at(0.5, 'Ward Clinic', rawCategory: 'Primary Health Center'),
        _at(3.0, 'Far Station', category: FacilityCategory.police),
        _at(1.5, 'Near Station', category: FacilityCategory.police),
      ],
      origin: _origin,
      category: FacilityCategory.police,
      isEmergency: true,
    );
    expect(picked?.name, 'Near Station');
  });

  test('falls back to the nearest facility of any kind', () {
    final picked = pickTriageFacility(
      facilities: [_at(0.5, 'Ward Clinic', rawCategory: 'Clinic')],
      origin: _origin,
      category: FacilityCategory.fire,
      isEmergency: false,
    );
    expect(picked?.name, 'Ward Clinic');
  });
}
