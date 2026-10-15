import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/data/models/geo_point.dart';
import 'package:rescue_911/src/utils/route_progress.dart';

/// A straight 2 km road due north from UNILAG, in 500 m steps.
final _road = [
  for (var i = 0; i <= 4; i++)
    GeoPoint(latitude: 6.5158 + i * 500 / 111195, longitude: 3.3896),
];

void main() {
  test('distance left is measured along the road', () {
    final progress = progressAlong(
      GeoPoint(latitude: 6.5158 + 750 / 111195, longitude: 3.3896),
      _road,
    )!;
    expect(progress.segmentIndex, 1);
    expect(progress.remainingMeters, closeTo(1250, 5));
    expect(progress.offByMeters, closeTo(0, 1));
  });

  test('a point beside the road reports how far off it is', () {
    // ~100 m east of the 1 km mark.
    final beside = GeoPoint(
      latitude: 6.5158 + 1000 / 111195,
      longitude: 3.3896 + 100 / 110500,
    );
    expect(distanceToLine(beside, _road), closeTo(100, 3));
    expect(progressAlong(beside, _road)!.remainingMeters, closeTo(1000, 5));
  });

  test('search starts from the last segment reached', () {
    final progress = progressAlong(
      GeoPoint(latitude: 6.5158 + 1800 / 111195, longitude: 3.3896),
      _road,
      fromIndex: 3,
    )!;
    expect(progress.segmentIndex, 3);
    expect(progress.remainingMeters, closeTo(200, 5));
  });

  test('bearing points the way of travel', () {
    expect(bearingDegrees(_road[0], _road[1]), closeTo(0, 0.5));
    expect(bearingDegrees(_road[1], _road[0]), closeTo(180, 0.5));
    const east = GeoPoint(latitude: 6.5158, longitude: 3.3906);
    expect(bearingDegrees(_road[0], east), closeTo(90, 0.5));
  });
}
