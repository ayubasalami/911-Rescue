import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/utils/map_zoom.dart';

void main() {
  const lagos = 6.52;

  test('a 750 m radius on a phone is street-to-neighbourhood scale', () {
    final zoom = zoomForRadius(
      latitude: lagos,
      radiusMeters: 750,
      viewportWidth: 390,
    );
    expect(zoom, closeTo(14.3, 0.1));
  });

  test('a larger radius zooms further out', () {
    double zoomFor(double radius) => zoomForRadius(
      latitude: lagos,
      radiusMeters: radius,
      viewportWidth: 390,
    );
    expect(zoomFor(1000), lessThan(zoomFor(500)));
  });

  test('a wider screen zooms in to keep the same area', () {
    double zoomFor(double width) =>
        zoomForRadius(latitude: lagos, radiusMeters: 750, viewportWidth: width);
    expect(zoomFor(800), greaterThan(zoomFor(390)));
  });

  test('stays where facility markers show and above street level', () {
    expect(
      zoomForRadius(latitude: lagos, radiusMeters: 50000, viewportWidth: 390),
      13,
    );
    expect(
      zoomForRadius(latitude: lagos, radiusMeters: 1, viewportWidth: 390),
      18,
    );
  });
}
