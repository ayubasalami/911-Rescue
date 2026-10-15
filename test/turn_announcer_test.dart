import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/data/models/access_analysis.dart';
import 'package:rescue_911/src/data/models/geo_point.dart';
import 'package:rescue_911/src/utils/turn_announcer.dart';

const _here = GeoPoint(latitude: 6.5158, longitude: 3.3896);

/// A point [meters] due north of [_here].
GeoPoint _north(double meters) =>
    GeoPoint(latitude: 6.5158 + meters / 111195, longitude: 3.3896);

void main() {
  test('reads street abbreviations in full', () {
    expect(
      spokenInstruction('Turn left onto  Herbert Macaulay Rd'),
      'Turn left onto Herbert Macaulay Road',
    );
    expect(
      spokenInstruction('Merge onto Third Mainland Expy'),
      contains('Expressway'),
    );
  });

  test('announces a turn within 160 m once, with the distance', () {
    final steps = [
      DirectionsStep(
        instruction: 'Turn right onto Akoka St',
        distanceMeters: 100,
        location: _north(150),
      ),
    ];
    final spoken = <int>{};
    expect(
      nextTurnAnnouncement(steps: steps, position: _here, spoken: spoken),
      'In 150 metres, turn right onto Akoka Street',
    );
    expect(
      nextTurnAnnouncement(steps: steps, position: _here, spoken: spoken),
      isNull,
    );
  });

  test('close to the turn it says just the instruction', () {
    final steps = [
      DirectionsStep(
        instruction: 'Turn left.',
        distanceMeters: 50,
        location: _north(30),
      ),
    ];
    expect(
      nextTurnAnnouncement(steps: steps, position: _here, spoken: {}),
      'Turn left.',
    );
  });

  test('stays quiet when the next turn is further than 160 m', () {
    final steps = [
      DirectionsStep(
        instruction: 'Turn left.',
        distanceMeters: 50,
        location: _north(400),
      ),
    ];
    expect(
      nextTurnAnnouncement(steps: steps, position: _here, spoken: {}),
      isNull,
    );
  });
}
