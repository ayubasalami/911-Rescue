import 'dart:math' as math;

/// Mapbox zoom levels the "show my location" view stays within: never so
/// far out that facility markers hide, never closer than street level.
const _minZoom = 13.0;
const _maxZoom = 18.0;

/// The zoom at which a screen [viewportWidth] logical pixels wide shows
/// [radiusMeters] either side of a point at [latitude].
///
/// Mapbox (512 px tiles) shows 2πR·cos(lat) / (512·2^z) metres per pixel at
/// zoom z; this solves that for the width spanning twice the radius.
double zoomForRadius({
  required double latitude,
  required double radiusMeters,
  required double viewportWidth,
}) {
  const earthRadius = 6378137.0;
  final metersAtZoomZero =
      2 * math.pi * earthRadius * math.cos(latitude * math.pi / 180) / 512;
  final zoom =
      math.log(metersAtZoomZero * viewportWidth / (2 * radiusMeters)) /
      math.ln2;
  return zoom.clamp(_minZoom, _maxZoom);
}
