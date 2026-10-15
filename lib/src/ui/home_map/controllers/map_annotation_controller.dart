import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/geo_point.dart';
import '../../../data/models/ping.dart';
import '../../../utils/route_progress.dart';
import '../../core/widgets/facility_category_glyph.dart';
import '../widgets/map_legend.dart';

mapbox.Point mapboxPointFrom(GeoPoint point) =>
    mapbox.Point(coordinates: mapbox.Position(point.longitude, point.latitude));

/// Rasterizes a facility category's glyph directly in its own color, with
/// no circle/badge behind it — matches 911rescueme.com's own map markers
/// (confirmed live: a plain red cross, no white badge or background
/// shape), rather than this app's earlier circle-badge treatment. Returns
/// the decoded [ui.Image] rather than an encoded format — callers pick
/// the encoding they need ([_pngBytes] for the native location puck,
/// [_mbxImageFrom] for a registered style image).
Future<ui.Image> _renderCategoryMarkerImage(FacilityCategory category) async {
  const size = 64.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
  paintFacilityCategoryGlyph(canvas, category, category.legendColor, size);
  final picture = recorder.endRecording();
  return picture.toImage(size.toInt(), size.toInt());
}

/// Rasterizes a map-pin glyph, used both for a dropped pin (bottom-anchored
/// via [PointAnnotationOptions.iconAnchor]) and for the native GPS location
/// puck, in [color]. Same [ui.Image]-returning convention as
/// [_renderCategoryMarkerImage].
Future<ui.Image> _renderLocationPinImage(Color color) async {
  const size = 96.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

  final icon = Icons.location_pin;
  final textPainter = TextPainter(textDirection: TextDirection.ltr)
    ..text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    )
    ..layout();
  textPainter.paint(
    canvas,
    Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
  );

  final picture = recorder.endRecording();
  return picture.toImage(size.toInt(), size.toInt());
}

/// The web's `--user-purple`, for the "You are here" marker.
const _userPurple = Color(0xFF7C3AED);

/// Pixel density the heading marker is drawn at — registered with the same
/// scale so it stays sharp.
const _markerScale = 3.0;

/// The web's `.user-heading-cone`: a 34 px wedge pointing up from the image
/// centre, fading out towards its tip. Rotated on the map to the heading.
Future<ui.Image> _renderHeadingConeImage() async {
  const size = 68.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_markerScale);
  const centre = Offset(size / 2, size / 2);
  final path = Path()
    ..moveTo(centre.dx - 17, centre.dy)
    ..lineTo(centre.dx + 17, centre.dy)
    ..lineTo(centre.dx, centre.dy - 34)
    ..close();
  canvas.drawPath(
    path,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(centre.dx, centre.dy - 34),
        centre,
        [_userPurple.withValues(alpha: 0), _userPurple.withValues(alpha: 0.32)],
        [0.05, 0.9],
      ),
  );
  final picture = recorder.endRecording();
  return picture.toImage(
    (size * _markerScale).toInt(),
    (size * _markerScale).toInt(),
  );
}

/// The web's `.user-heading-dot` and "You are here" label: a 16 px purple
/// dot with a white ring centred in the image, the pill underneath.
Future<ui.Image> _renderHeadingDotImage() async {
  const width = 120.0;
  const height = 68.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_markerScale);
  const centre = Offset(width / 2, height / 2);

  canvas
    ..drawCircle(
      centre,
      9,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    )
    ..drawCircle(centre, 8, Paint()..color = Colors.white)
    ..drawCircle(centre, 5, Paint()..color = _userPurple);

  final label = TextPainter(
    textDirection: TextDirection.ltr,
    text: const TextSpan(
      text: 'You are here',
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  )..layout();
  final pill = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(centre.dx, centre.dy + 14 + (label.height + 4) / 2),
      width: label.width + 16,
      height: label.height + 4,
    ),
    const Radius.circular(10),
  );
  canvas
    ..drawRRect(
      pill.shift(const Offset(0, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    )
    ..drawRRect(pill, Paint()..color = _userPurple);
  label.paint(canvas, Offset(centre.dx - label.width / 2, pill.top + 2));

  final picture = recorder.endRecording();
  return picture.toImage(
    (width * _markerScale).toInt(),
    (height * _markerScale).toInt(),
  );
}

/// The web's `.responder-dot` and name label: a 16 px accent dot with a
/// white ring centred in the image, the pill underneath.
Future<ui.Image> _renderResponderImage(String name, Color color) async {
  final label = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
    text: TextSpan(
      text: name,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  )..layout(maxWidth: 160);
  final width = math.max(40.0, label.width + 20);
  const height = 68.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_markerScale);
  final centre = Offset(width / 2, height / 2);

  canvas
    ..drawCircle(
      centre,
      9,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    )
    ..drawCircle(centre, 8, Paint()..color = Colors.white)
    ..drawCircle(centre, 5.5, Paint()..color = color);

  final pill = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(centre.dx, centre.dy + 14 + (label.height + 4) / 2),
      width: label.width + 14,
      height: label.height + 4,
    ),
    const Radius.circular(10),
  );
  canvas
    ..drawRRect(
      pill.shift(const Offset(0, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    )
    ..drawRRect(pill, Paint()..color = color);
  label.paint(canvas, Offset(centre.dx - label.width / 2, pill.top + 2));

  final picture = recorder.endRecording();
  return picture.toImage(
    (width * _markerScale).toInt(),
    (height * _markerScale).toInt(),
  );
}

/// A circle of [radiusMeters] around [centre] as a polygon ring — the
/// responder's GPS accuracy.
List<mapbox.Position> _circleRing(GeoPoint centre, double radiusMeters) {
  const steps = 48;
  final latRadius = radiusMeters / 111320;
  final lngRadius =
      radiusMeters / (111320 * math.cos(centre.latitude * math.pi / 180));
  return [
    for (var i = 0; i <= steps; i++)
      mapbox.Position(
        centre.longitude + lngRadius * math.cos(2 * math.pi * i / steps),
        centre.latitude + latRadius * math.sin(2 * math.pi * i / steps),
      ),
  ];
}

/// Blends [target] into [previous] by [weight] on the circle — the web's
/// heading smoothing, so a jittery GPS heading doesn't swing the map.
double _blendBearing(double? previous, double target, [double weight = 0.25]) {
  if (previous == null) return target;
  final p = previous * math.pi / 180;
  final t = target * math.pi / 180;
  final y = (1 - weight) * math.sin(p) + weight * math.sin(t);
  final x = (1 - weight) * math.cos(p) + weight * math.cos(t);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// The smaller angle between two bearings, 0–180°.
double bearingGap(double a, double b) => ((a - b + 540) % 360 - 180).abs();

Future<Uint8List> _pngBytes(ui.Image image) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// [mapbox.MbxImage]'s own doc comment claims `data` wants raw,
/// premultiplied-alpha RGBA pixels — confirmed wrong by a live
/// `PlatformException(0, "Could not initialize the image from the
/// specified data.")`: this plugin's native side actually decodes `data`
/// as an *encoded* image (`UIImage(data:)` on iOS,
/// `BitmapFactory.decodeByteArray` on Android), i.e. plain PNG bytes, same
/// as [_pngBytes]. `width`/`height` aren't used for decoding either
/// platform — both derive them from the decoded image — but are required
/// fields on [mapbox.MbxImage] regardless.
Future<mapbox.MbxImage> _mbxImageFrom(ui.Image image) async {
  return mapbox.MbxImage(
    width: image.width,
    height: image.height,
    data: await _pngBytes(image),
  );
}

/// Owns every direct interaction with the Mapbox SDK's platform view and
/// annotation managers: rendering facility pins, the driving-time isochrone
/// polygon, route lines, the location puck, and camera moves.
///
/// This is deliberately not a ViewModel — it holds live platform view
/// objects (`MapboxMap`, annotation managers) that a Riverpod ViewModel
/// shouldn't own, and has no business/app state of its own. [HomeMapScreen]
/// owns one instance and calls into it in reaction to user input and to
/// [HomeMapViewModel] state changes.
class MapAnnotationController {
  mapbox.MapboxMap? _map;
  mapbox.PointAnnotationManager? _facilityManager;
  mapbox.PointAnnotationManager? _originManager;
  mapbox.PolygonAnnotationManager? _polygonManager;
  mapbox.PolylineAnnotationManager? _polylineManager;

  /// The part of a tracked route already driven, grey under the road
  /// ahead — the web tracker's trimmed line. Created before
  /// [_polylineManager] so it draws beneath it.
  mapbox.PolylineAnnotationManager? _travelledManager;

  /// The dashed "Shortest Route" to the nearest facility drawn by an
  /// analysis — its own manager because the dash pattern is set per
  /// manager, not per line.
  mapbox.PolylineAnnotationManager? _analysisRouteManager;

  /// Separate from [_polylineManager] deliberately — that one is deleted
  /// and recreated on nearly every Go to Help update, but the Lagos
  /// boundary is static and toggled independently; sharing a manager would
  /// mean every route change wipes the boundary outline too.
  mapbox.PolylineAnnotationManager? _boundaryManager;

  /// An accepted ping's responder: their road route to the user (solid) or,
  /// until one comes back, a dashed straight line; their GPS accuracy; and
  /// the named dot.
  mapbox.PolylineAnnotationManager? _responderRouteManager;
  mapbox.PolylineAnnotationManager? _responderLineManager;
  mapbox.PolygonAnnotationManager? _responderAccuracyManager;
  mapbox.PointAnnotationManager? _responderManager;
  ResponderTrack? _responderTrack;
  Future<void> _responderSync = Future.value();

  /// The tracked "You are here" marker — on top of everything, and in place
  /// of the location puck while following a route.
  mapbox.PointAnnotationManager? _headingManager;
  mapbox.PointAnnotation? _headingCone;
  mapbox.PointAnnotation? _headingDot;
  GeoPoint? _headingPoint;
  double? _headingDegrees;
  bool _puckHidden = false;

  /// Marker updates run one at a time, so overlapping rebuilds can't create
  /// it twice.
  Future<void> _headingSync = Future.value();

  static const _headingConeImageId = 'user-heading-cone';
  static const _headingDotImageId = 'user-heading-dot';

  /// Follow-your-direction: the smoothed heading, the last one asked for,
  /// and the bearing the map was last turned to — anything else means the
  /// user rotated it by hand.
  double? _smoothedHeading;
  double? _followTarget;
  double _bearingSetByFollow = 0;
  double get bearingSetByFollow => _bearingSetByFollow;
  List<GeoPoint>? _lastBoundary;

  List<Facility> _lastSourceFacilities = const [];
  FacilityCategory? _lastAppliedFilter;
  final Map<String, Facility> _annotationFacilities = {};

  /// Style image IDs already registered via [_ensureStyleImage] — an
  /// annotation referencing one of these by [mapbox.PointAnnotationOptions
  /// .iconImage] is guaranteed to find it, since registration is always
  /// awaited before the annotation referencing it is created. That's the
  /// actual fix for the SDK's "Required image … is missing" warning: the
  /// previous per-annotation `image: Uint8List` path left the native image
  /// registration's timing up to the plugin, which could lose the race
  /// against the very next style render pass.
  final Set<String> _registeredStyleImages = {};

  static String _markerImageId(FacilityCategory category) =>
      'facility-marker-${category.name}';
  static const _pinDropImageId = 'location-pin-marker';

  Future<void> _ensureStyleImage(
    String imageId,
    Future<ui.Image> Function() render, {
    double scale = 1.0,
  }) async {
    if (_registeredStyleImages.contains(imageId)) return;
    final map = _map;
    if (map == null) return;
    final mbxImage = await _mbxImageFrom(await render());
    await map.style.addStyleImage(
      imageId,
      scale,
      mbxImage,
      false,
      [],
      [],
      null,
    );
    _registeredStyleImages.add(imageId);
  }

  Future<void> _ensureMarkerImage(FacilityCategory category) =>
      _ensureStyleImage(
        _markerImageId(category),
        () => _renderCategoryMarkerImage(category),
      );

  Future<void> _ensurePinDropImage() => _ensureStyleImage(
    _pinDropImageId,
    () => _renderLocationPinImage(_palette.primary),
  );

  /// The web swaps CARTO's voyager and dark_all tiles; these are the
  /// closest Mapbox styles.
  static String styleUriFor({required bool dark}) =>
      dark ? mapbox.MapboxStyles.DARK : mapbox.MapboxStyles.MAPBOX_STREETS;

  /// Route and pin colours for the current theme.
  AppPalette _palette = AppPalette.light;

  /// Whether the loaded style is the dark one, and whether it should be.
  bool _styleDark = false;
  bool _wantDark = false;
  bool _restyling = false;

  /// What's drawn, kept so a style switch — which wipes the map's images
  /// and layers — can draw it all again.
  List<IsochroneRing>? _lastRings;
  TransportMode? _lastRingsMode;
  List<GeoPoint>? _lastRoute;
  RouteProgress? _lastProgress;
  List<GeoPoint>? _lastAnalysisRoute;

  GeoPoint? _lastDroppedPin;

  static const _trafficSourceId = 'traffic-source';
  static const _trafficLayerId = 'traffic-layer';
  bool _trafficLayerAdded = false;
  bool? _lastTrafficVisible;

  Facility? facilityForAnnotation(String annotationId) =>
      _annotationFacilities[annotationId];

  /// [dark] is the style the map was created with ([styleUriFor]).
  Future<void> onMapCreated(
    mapbox.MapboxMap mapboxMap, {
    required bool dark,
    required void Function(mapbox.PointAnnotation) onFacilityTap,
  }) async {
    _map = mapboxMap;
    _styleDark = dark;
    // Mapbox's default top-left scale bar sits under the status bar; the
    // web map has none.
    await mapboxMap.scaleBar.updateSettings(
      mapbox.ScaleBarSettings(enabled: false),
    );
    _polygonManager = await mapboxMap.annotations
        .createPolygonAnnotationManager();

    final facilityManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _facilityManager = facilityManager;
    facilityManager.tapEvents(onTap: onFacilityTap);

    _originManager = await mapboxMap.annotations.createPointAnnotationManager();

    _travelledManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    _polylineManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();

    final analysisRouteManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    // The web's `dashArray: 5,5` at weight 4 — Mapbox measures dashes in
    // line widths.
    await analysisRouteManager.setLineDasharray([1.25, 1.25]);
    _analysisRouteManager = analysisRouteManager;

    final boundaryManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    // The web's `dashArray: 5,10` at weight 3 — Mapbox measures dashes in
    // line widths.
    await boundaryManager.setLineDasharray([5 / 3, 10 / 3]);
    _boundaryManager = boundaryManager;

    _responderAccuracyManager = await mapboxMap.annotations
        .createPolygonAnnotationManager();
    _responderRouteManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    final responderLineManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    // The web's `dashArray: 6,6` at weight 2.
    await responderLineManager.setLineDasharray([3, 3]);
    _responderLineManager = responderLineManager;
    final responderManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    await responderManager.setIconAllowOverlap(true);
    await responderManager.setIconIgnorePlacement(true);
    _responderManager = responderManager;

    final headingManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    // The cone turns with the map, so its rotation is a compass bearing.
    await headingManager.setIconRotationAlignment(
      mapbox.IconRotationAlignment.MAP,
    );
    await headingManager.setIconAllowOverlap(true);
    await headingManager.setIconIgnorePlacement(true);
    _headingManager = headingManager;

    await _updateLocationPuck();
    // The theme may have changed while the map was being created.
    await _applyTheme();
  }

  Future<void> _updateLocationPuck() async {
    final map = _map;
    if (map == null) return;
    await map.location.updateSettings(
      mapbox.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: false,
        locationPuck: mapbox.LocationPuck(
          locationPuck2D: mapbox.LocationPuck2D(
            // The location puck is a separate native codepath from style
            // annotations — it decodes an encoded image directly rather
            // than looking one up via addStyleImage, so this one still
            // wants PNG bytes, not a registered style image.
            topImage: await _pngBytes(
              await _renderLocationPinImage(_palette.primary),
            ),
          ),
        ),
      ),
    );
  }

  /// Switches the map to [palette]'s theme: the dark or light style, and
  /// the web's route and pin colours for it. Safe to call on every build.
  Future<void> setTheme(AppPalette palette, {required bool dark}) async {
    _wantDark = dark;
    if (_map == null) {
      _palette = palette;
      _styleDark = dark;
      return;
    }
    if (_styleDark == dark) return;
    _palette = palette;
    await _applyTheme();
  }

  /// Loads the wanted style, then draws everything again — a style load
  /// drops the registered marker images, the traffic layer and (on some
  /// SDK versions) the annotations. Loops so a toggle made mid-load still
  /// lands on the right style.
  Future<void> _applyTheme() async {
    final map = _map;
    if (map == null || _restyling) return;
    _restyling = true;
    try {
      while (_styleDark != _wantDark) {
        _styleDark = _wantDark;
        await map.loadStyleURI(styleUriFor(dark: _styleDark));
        await _redrawAll();
      }
    } finally {
      _restyling = false;
    }
  }

  Future<void> _redrawAll() async {
    _registeredStyleImages.clear();
    await _updateLocationPuck();

    final responder = _responderTrack;
    _responderTrack = null;
    if (responder != null) await syncResponder(responder);

    final headingPoint = _headingPoint;
    final headingDegrees = _headingDegrees;
    _headingPoint = null;
    _headingDegrees = null;
    _headingCone = null;
    _headingDot = null;
    _puckHidden = false;
    await _headingManager?.deleteAll();
    if (headingPoint != null) {
      await syncHeadingMarker(headingPoint, headingDegrees);
    }

    final facilities = _lastSourceFacilities;
    _lastSourceFacilities = const [];
    await syncFacilityPins(facilities, _lastAppliedFilter, force: true);

    final pin = _lastDroppedPin;
    _lastDroppedPin = null;
    await _originManager?.deleteAll();
    if (pin != null) await syncDroppedPin(pin);

    final boundary = _lastBoundary;
    _lastBoundary = null;
    await _boundaryManager?.deleteAll();
    if (boundary != null) await syncBoundary(boundary);

    final traffic = _lastTrafficVisible;
    _trafficLayerAdded = false;
    _lastTrafficVisible = null;
    if (traffic ?? false) await setTrafficVisible(true);

    final rings = _lastRings;
    final mode = _lastRingsMode;
    await _polygonManager?.deleteAll();
    if (rings != null && mode != null) await renderIsochrone(rings, mode);

    final route = _lastRoute;
    final progress = _lastProgress;
    _lastRoute = null;
    _lastProgress = null;
    await _polylineManager?.deleteAll();
    await _travelledManager?.deleteAll();
    if (route != null) {
      await (progress == null
          ? renderRoute(route)
          : renderRouteProgress(route, progress));
    }

    final analysisRoute = _lastAnalysisRoute;
    await _analysisRouteManager?.deleteAll();
    if (analysisRoute != null) await renderAnalysisRoute(analysisRoute);
  }

  /// Shows (or, with a null [point], removes) the web's purple "You are
  /// here" dot with a cone towards [heading]. Hides the location puck while
  /// shown. Safe to call on every build.
  Future<void> syncHeadingMarker(GeoPoint? point, double? heading) {
    if (identical(point, _headingPoint) && heading == _headingDegrees) {
      return _headingSync;
    }
    _headingPoint = point;
    _headingDegrees = heading;
    return _headingSync = _headingSync.then(
      (_) => _applyHeadingMarker(point, heading),
    );
  }

  Future<void> _applyHeadingMarker(GeoPoint? point, double? heading) async {
    final manager = _headingManager;
    final map = _map;
    if (manager == null || map == null) return;

    if (point == null) {
      await manager.deleteAll();
      _headingCone = null;
      _headingDot = null;
      if (_puckHidden) {
        _puckHidden = false;
        await _updateLocationPuck();
      }
      return;
    }

    if (!_puckHidden) {
      _puckHidden = true;
      await map.location.updateSettings(
        mapbox.LocationComponentSettings(enabled: false),
      );
    }
    await _ensureStyleImage(
      _headingConeImageId,
      _renderHeadingConeImage,
      scale: _markerScale,
    );
    await _ensureStyleImage(
      _headingDotImageId,
      _renderHeadingDotImage,
      scale: _markerScale,
    );

    final geometry = mapboxPointFrom(point);
    if (heading == null) {
      if (_headingCone case final cone?) await manager.delete(cone);
      _headingCone = null;
    } else if (_headingCone case final cone?) {
      cone
        ..geometry = geometry
        ..iconRotate = heading;
      await manager.update(cone);
    } else {
      _headingCone = await manager.create(
        mapbox.PointAnnotationOptions(
          geometry: geometry,
          iconImage: _headingConeImageId,
          iconRotate: heading,
          symbolSortKey: 0,
        ),
      );
    }

    if (_headingDot case final dot?) {
      dot.geometry = geometry;
      await manager.update(dot);
    } else {
      _headingDot = await manager.create(
        mapbox.PointAnnotationOptions(
          geometry: geometry,
          iconImage: _headingDotImageId,
          symbolSortKey: 1,
        ),
      );
    }
  }

  /// Draws (or, with null, clears) an accepted ping's responder, as the web
  /// does on each status poll.
  Future<void> syncResponder(ResponderTrack? track) {
    if (identical(track, _responderTrack)) return _responderSync;
    _responderTrack = track;
    return _responderSync = _responderSync.then((_) => _applyResponder(track));
  }

  Future<void> _applyResponder(ResponderTrack? track) async {
    final marker = _responderManager;
    final accuracy = _responderAccuracyManager;
    final routeManager = _responderRouteManager;
    final lineManager = _responderLineManager;
    if (marker == null ||
        accuracy == null ||
        routeManager == null ||
        lineManager == null) {
      return;
    }
    await marker.deleteAll();
    await accuracy.deleteAll();
    await routeManager.deleteAll();
    await lineManager.deleteAll();
    if (track == null) return;

    mapbox.LineString line(List<GeoPoint> points) => mapbox.LineString(
      coordinates: [
        for (final point in points)
          mapbox.Position(point.longitude, point.latitude),
      ],
    );

    final route = track.route;
    if (route != null && route.length >= 2) {
      await routeManager.create(
        mapbox.PolylineAnnotationOptions(
          geometry: line(route),
          lineColor: _palette.primary.toARGB32(),
          lineWidth: 4,
          lineOpacity: 0.85,
        ),
      );
    } else {
      await lineManager.create(
        mapbox.PolylineAnnotationOptions(
          geometry: line([track.user, track.position]),
          lineColor: _palette.primary.toARGB32(),
          lineWidth: 2,
          lineOpacity: 0.6,
        ),
      );
    }

    final meters = track.accuracyMeters;
    if (meters != null && meters > 25) {
      await accuracy.create(
        mapbox.PolygonAnnotationOptions(
          geometry: mapbox.Polygon(
            coordinates: [_circleRing(track.position, meters)],
          ),
          fillColor: _palette.primary.toARGB32(),
          fillOpacity: 0.08,
          fillOutlineColor: _palette.primary.withValues(alpha: 0.5).toARGB32(),
        ),
      );
    }

    // One image per name and colour, so a theme switch or another
    // responder gets its own.
    final imageId =
        'responder-${track.name.hashCode}-${_palette.primary.toARGB32()}';
    await _ensureStyleImage(
      imageId,
      () => _renderResponderImage(track.name, _palette.primary),
      scale: _markerScale,
    );
    await marker.create(
      mapbox.PointAnnotationOptions(
        geometry: mapboxPointFrom(track.position),
        iconImage: imageId,
      ),
    );
  }

  /// Turns the map so [heading] points up — smoothed, and only once it's
  /// more than 3° off, as on the web. Safe to call on every build.
  Future<void> followHeading(double heading) async {
    final map = _map;
    if (map == null || heading == _followTarget) return;
    _followTarget = heading;
    _smoothedHeading = _blendBearing(_smoothedHeading, heading);
    final target = _smoothedHeading!;
    final current = (await map.getCameraState()).bearing;
    if (bearingGap(current, target) < 3) return;
    _bearingSetByFollow = target;
    await map.setCamera(mapbox.CameraOptions(bearing: target));
  }

  /// Follow mode just switched on: remember where the map points now, so
  /// only a later hand rotation counts as leaving it.
  Future<void> beginFollow() async {
    final map = _map;
    if (map == null) return;
    _followTarget = null;
    _bearingSetByFollow = (await map.getCameraState()).bearing;
  }

  /// Back to north up.
  Future<void> resetNorth() async {
    _smoothedHeading = null;
    _followTarget = null;
    _bearingSetByFollow = 0;
    await _map?.easeTo(
      mapbox.CameraOptions(bearing: 0),
      mapbox.MapAnimationOptions(duration: 300),
    );
  }

  /// [shiftDown] lands [point] that many pixels below screen center instead
  /// of on it — for points that open a popup anchored *above* them, so the
  /// card itself ends up roughly centered rather than crowding the top.
  Future<void> flyTo(GeoPoint point, {double shiftDown = 0}) async {
    final map = _map;
    if (map == null) return;
    // At least 13 (HomeMapScreen's facility-marker threshold), so centering
    // on a point reveals nearby facilities — but never zooms *out* if the
    // user is already closer than that.
    final currentZoom = (await map.getCameraState()).zoom;
    // easeTo, not flyTo: flyTo's arc zooms out mid-flight, dipping below
    // the marker threshold and back, which wiped and redrew every facility
    // marker during the animation.
    await map.easeTo(
      mapbox.CameraOptions(
        center: mapboxPointFrom(point),
        zoom: currentZoom > 13 ? currentZoom : 13,
        // Top padding moves the camera's reference center down by half
        // its value. Always set explicitly (zero when not shifting) since
        // Mapbox keeps the last padding for later camera moves otherwise.
        padding: _edgeInsets(top: shiftDown * 2),
      ),
      mapbox.MapAnimationOptions(duration: 800),
    );
  }

  static mapbox.MbxEdgeInsets _edgeInsets({double top = 0}) =>
      mapbox.MbxEdgeInsets(top: top, left: 0, bottom: 0, right: 0);

  /// Zooms/pans to fit every point in [points] on screen at once — used for
  /// the Go to Help route overview, matching the web platform's zoom-out
  /// when a route is active.
  Future<void> flyToBounds(
    List<GeoPoint> points, {
    double padding = 60,
    double? maxZoom,
  }) async {
    final map = _map;
    if (map == null || points.isEmpty) return;
    final coordinates = points.map(mapboxPointFrom).toList();
    final camera = await map.cameraForCoordinatesPadding(
      coordinates,
      mapbox.CameraOptions(),
      mapbox.MbxEdgeInsets(
        top: padding,
        left: padding,
        bottom: padding,
        right: padding,
      ),
      maxZoom,
      null,
    );
    // Clear any shift left over from [flyTo] — the fit above assumes an
    // unpadded view.
    camera.padding = _edgeInsets();
    await map.flyTo(camera, mapbox.MapAnimationOptions(duration: 800));
  }

  /// The on-screen pixel for [point], or null if the map isn't ready yet.
  Future<Offset?> pixelForCoordinate(GeoPoint point) async {
    final map = _map;
    if (map == null) return null;
    final pixel = await map.pixelForCoordinate(mapboxPointFrom(point));
    return Offset(pixel.x, pixel.y);
  }

  Future<void> syncFacilityPins(
    List<Facility> facilities,
    FacilityCategory? filter, {
    bool force = false,
  }) async {
    final manager = _facilityManager;
    if (manager == null) return;
    if (!force &&
        identical(facilities, _lastSourceFacilities) &&
        _lastAppliedFilter == filter) {
      return;
    }
    _lastSourceFacilities = facilities;
    _lastAppliedFilter = filter;

    final visible = [
      for (final facility in facilities)
        if (filter == null || facility.category == filter) facility,
    ];

    // Registered (and awaited) before any annotation referencing it is
    // created — see [_registeredStyleImages].
    for (final category in visible.map((f) => f.category).toSet()) {
      await _ensureMarkerImage(category);
    }

    await manager.deleteAll();
    _annotationFacilities.clear();
    final created = await manager.createMulti([
      for (final facility in visible)
        mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position(facility.longitude, facility.latitude),
          ),
          iconImage: _markerImageId(facility.category),
          // The glyph now fills its marker image edge to edge (no circle
          // padding around it like before), so the same iconSize as before
          // reads much bigger on screen — scaled down to compensate.
          iconSize: 0.35,
        ),
    ]);
    for (final (index, annotation) in created.indexed) {
      if (annotation != null) {
        _annotationFacilities[annotation.id] = visible[index];
      }
    }
  }

  /// Renders (or clears, when [point] is null) a pin marker at a dropped
  /// point — a real map annotation anchored to the coordinate, matching how
  /// facility markers work, rather than a screen-space overlay that doesn't
  /// track the map. Used only for a dropped pin, not "Your Location" (which
  /// already has its own live location puck) or a tapped facility (which
  /// already has its own permanent marker).
  Future<void> syncDroppedPin(GeoPoint? point) async {
    final manager = _originManager;
    if (manager == null) return;
    if (identical(point, _lastDroppedPin)) return;
    _lastDroppedPin = point;

    await manager.deleteAll();
    if (point == null) return;

    await _ensurePinDropImage();
    await manager.create(
      mapbox.PointAnnotationOptions(
        geometry: mapboxPointFrom(point),
        iconImage: _pinDropImageId,
        iconSize: 0.6,
        iconAnchor: mapbox.IconAnchor.BOTTOM,
      ),
    );
  }

  /// Shows or hides Mapbox's live traffic layer — added once, on top of the
  /// current style, then just toggled visible/hidden afterward rather than
  /// re-added each time. Unlike the rest of this controller, this is a real
  /// network-backed Mapbox tileset (`mapbox://mapbox.mapbox-traffic-v1`),
  /// not a purely local operation.
  Future<void> setTrafficVisible(bool visible) async {
    final map = _map;
    if (map == null || _lastTrafficVisible == visible) return;
    _lastTrafficVisible = visible;

    if (!_trafficLayerAdded) {
      if (!visible) return;
      await map.style.addSource(
        mapbox.VectorSource(
          id: _trafficSourceId,
          url: 'mapbox://mapbox.mapbox-traffic-v1',
        ),
      );
      await map.style.addLayer(
        mapbox.LineLayer(
          id: _trafficLayerId,
          sourceId: _trafficSourceId,
          sourceLayer: 'traffic',
          lineWidth: 2.5,
          lineColorExpression: const [
            'match',
            ['get', 'congestion'],
            'low',
            '#2ECC71',
            'moderate',
            '#F1C40F',
            'heavy',
            '#E67E22',
            'severe',
            '#C0392B',
            '#2ECC71',
          ],
        ),
      );
      _trafficLayerAdded = true;
      return;
    }

    await map.style.setStyleLayerProperty(
      _trafficLayerId,
      'visibility',
      visible ? 'visible' : 'none',
    );
  }

  /// The analysis time bands, largest first so the smaller ones sit on
  /// top — the web's colours for [mode] at 30% fill with a matching
  /// outline.
  Future<void> renderIsochrone(
    List<IsochroneRing> rings,
    TransportMode mode,
  ) async {
    final manager = _polygonManager;
    if (manager == null) return;
    _lastRings = rings;
    _lastRingsMode = mode;
    await manager.deleteAll();
    final sorted = [...rings]..sort((a, b) => b.minutes.compareTo(a.minutes));
    await manager.createMulti([
      for (final ring in sorted)
        mapbox.PolygonAnnotationOptions(
          geometry: mapbox.Polygon(
            coordinates: [
              [
                for (final point in ring.points)
                  mapbox.Position(point.longitude, point.latitude),
              ],
            ],
          ),
          fillColor: mode.bandColor(ring.minutes),
          fillOpacity: 0.3,
          fillOutlineColor: mode.bandColor(ring.minutes),
        ),
    ]);
  }

  /// The analysis's dashed "Shortest Route" to the nearest facility, in
  /// the web's `--route-color` (blue, or yellow in dark).
  Future<void> renderAnalysisRoute(List<GeoPoint> points) async {
    final manager = _analysisRouteManager;
    if (manager == null) return;
    _lastAnalysisRoute = points;
    await manager.deleteAll();
    await manager.create(
      mapbox.PolylineAnnotationOptions(
        geometry: mapbox.LineString(
          coordinates: [
            for (final point in points)
              mapbox.Position(point.longitude, point.latitude),
          ],
        ),
        lineColor: _palette.route.toARGB32(),
        lineWidth: 4,
        lineOpacity: 0.9,
      ),
    );
  }

  Future<void> clearAnalysisRoute() async {
    _lastAnalysisRoute = null;
    await _analysisRouteManager?.deleteAll();
  }

  /// Skips the redraw when it's the same line already drawn — the screen
  /// calls this on every rebuild while tracking.
  Future<void> renderRoute(List<GeoPoint> points) async {
    final manager = _polylineManager;
    if (manager == null) return;
    if (identical(points, _lastRoute) && _lastProgress == null) return;
    _lastRoute = points;
    _lastProgress = null;
    await _travelledManager?.deleteAll();
    await manager.deleteAll();
    await manager.create(
      mapbox.PolylineAnnotationOptions(
        geometry: mapbox.LineString(
          coordinates: [
            for (final point in points)
              mapbox.Position(point.longitude, point.latitude),
          ],
        ),
        // The web's `--accent-green` (#0a5, #0f8 in dark) at weight 5,
        // opacity 0.9. Note the Live Traffic layer paints low-congestion
        // roads a similar green (#2ECC71), so with traffic on, a route
        // along a clear road can blend into it.
        lineColor: _palette.accentGreen.toARGB32(),
        lineWidth: 5,
        lineOpacity: 0.9,
      ),
    );
  }

  /// A tracked route split at [progress]: the driven part grey (the web's
  /// `#8d96a0` at 55%), the road ahead in the route colour.
  Future<void> renderRouteProgress(
    List<GeoPoint> points,
    RouteProgress progress,
  ) async {
    final ahead = _polylineManager;
    final travelled = _travelledManager;
    if (ahead == null || travelled == null) return;
    if (identical(points, _lastRoute) && identical(progress, _lastProgress)) {
      return;
    }
    _lastRoute = points;
    _lastProgress = progress;
    final split = progress.segmentIndex + 1;

    mapbox.LineString line(Iterable<GeoPoint> part) => mapbox.LineString(
      coordinates: [
        for (final point in part)
          mapbox.Position(point.longitude, point.latitude),
      ],
    );

    await travelled.deleteAll();
    await travelled.create(
      mapbox.PolylineAnnotationOptions(
        geometry: line([...points.take(split), progress.foot]),
        lineColor: const Color(0xFF8D96A0).toARGB32(),
        lineWidth: 5,
        lineOpacity: 0.55,
      ),
    );
    await ahead.deleteAll();
    await ahead.create(
      mapbox.PolylineAnnotationOptions(
        geometry: line([progress.foot, ...points.skip(split)]),
        lineColor: _palette.accentGreen.toARGB32(),
        lineWidth: 5,
        lineOpacity: 0.9,
      ),
    );
  }

  Future<void> clearRoute() async {
    _lastRoute = null;
    _lastProgress = null;
    await _travelledManager?.deleteAll();
    await _polylineManager?.deleteAll();
  }

  Future<void> clearIsochroneAndRoute() async {
    _lastRings = null;
    _lastRingsMode = null;
    _lastRoute = null;
    _lastProgress = null;
    _lastAnalysisRoute = null;
    await _travelledManager?.deleteAll();
    await _polygonManager?.deleteAll();
    await _polylineManager?.deleteAll();
    await _analysisRouteManager?.deleteAll();
  }

  /// Renders (or clears, when [ring] is null) the Lagos state boundary as
  /// an outline — a plain [PolylineAnnotationOptions] rather than a filled
  /// [PolygonAnnotationOptions], since a fill would obscure everything
  /// inside it. Dashed cyan at width 3, as on the web (the dash pattern is
  /// set on [_boundaryManager]).
  Future<void> syncBoundary(List<GeoPoint>? ring) async {
    final manager = _boundaryManager;
    if (manager == null) return;
    if (identical(ring, _lastBoundary)) return;
    _lastBoundary = ring;

    await manager.deleteAll();
    if (ring == null || ring.isEmpty) return;

    // Close the ring so the outline doesn't have a visible gap between the
    // last and first point. Always appends rather than checking whether
    // it's already closed — GeoPoint has no value equality, and a
    // duplicate final point is harmless for a polyline.
    final closed = [...ring, ring.first];
    await manager.create(
      mapbox.PolylineAnnotationOptions(
        geometry: mapbox.LineString(
          coordinates: [
            for (final point in closed)
              mapbox.Position(point.longitude, point.latitude),
          ],
        ),
        lineColor: _palette.boundary.toARGB32(),
        lineWidth: 3,
      ),
    );
  }
}
