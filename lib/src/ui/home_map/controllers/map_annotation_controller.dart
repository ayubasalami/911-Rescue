import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/geo_point.dart';
import '../../core/widgets/facility_category_glyph.dart';
import '../widgets/map_legend.dart';

mapbox.Point mapboxPointFrom(GeoPoint point) =>
    mapbox.Point(coordinates: mapbox.Position(point.longitude, point.latitude));

int _colorForBandMinutes(int minutes) => TimeBand.bands
    .firstWhere(
      (band) => band.maxMinutes == minutes,
      orElse: () => TimeBand.bands.last,
    )
    .color;

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
/// puck. Same [ui.Image]-returning convention as [_renderCategoryMarkerImage].
Future<ui.Image> _renderLocationPinImage() async {
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
        color: AppColors.primary,
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

  /// Separate from [_polylineManager] deliberately — that one is deleted
  /// and recreated on nearly every Go to Help update, but the Lagos
  /// boundary is static and toggled independently; sharing a manager would
  /// mean every route change wipes the boundary outline too.
  mapbox.PolylineAnnotationManager? _boundaryManager;
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
    Future<ui.Image> Function() render,
  ) async {
    if (_registeredStyleImages.contains(imageId)) return;
    final map = _map;
    if (map == null) return;
    final mbxImage = await _mbxImageFrom(await render());
    await map.style.addStyleImage(imageId, 1.0, mbxImage, false, [], [], null);
    _registeredStyleImages.add(imageId);
  }

  Future<void> _ensureMarkerImage(FacilityCategory category) =>
      _ensureStyleImage(
        _markerImageId(category),
        () => _renderCategoryMarkerImage(category),
      );

  Future<void> _ensurePinDropImage() =>
      _ensureStyleImage(_pinDropImageId, _renderLocationPinImage);

  GeoPoint? _lastDroppedPin;

  static const _trafficSourceId = 'traffic-source';
  static const _trafficLayerId = 'traffic-layer';
  bool _trafficLayerAdded = false;
  bool? _lastTrafficVisible;

  Facility? facilityForAnnotation(String annotationId) =>
      _annotationFacilities[annotationId];

  Future<void> onMapCreated(
    mapbox.MapboxMap mapboxMap, {
    required void Function(mapbox.PointAnnotation) onFacilityTap,
  }) async {
    _map = mapboxMap;
    _polygonManager = await mapboxMap.annotations
        .createPolygonAnnotationManager();

    final facilityManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _facilityManager = facilityManager;
    facilityManager.tapEvents(onTap: onFacilityTap);

    _originManager = await mapboxMap.annotations.createPointAnnotationManager();

    _polylineManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();

    _boundaryManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();

    await mapboxMap.location.updateSettings(
      mapbox.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: false,
        locationPuck: mapbox.LocationPuck(
          locationPuck2D: mapbox.LocationPuck2D(
            // The location puck is a separate native codepath from style
            // annotations — it decodes an encoded image directly rather
            // than looking one up via addStyleImage, so this one still
            // wants PNG bytes, not a registered style image.
            topImage: await _pngBytes(await _renderLocationPinImage()),
          ),
        ),
      ),
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
  Future<void> flyToBounds(List<GeoPoint> points, {double padding = 60}) async {
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
      null,
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
    FacilityCategory? filter,
  ) async {
    final manager = _facilityManager;
    if (manager == null) return;
    if (identical(facilities, _lastSourceFacilities) &&
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

  Future<void> renderIsochrone(List<IsochroneRing> rings) async {
    final manager = _polygonManager;
    if (manager == null) return;
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
          fillColor: _colorForBandMinutes(ring.minutes),
          fillOpacity: 0.35,
        ),
    ]);
  }

  static const _routeGreen = Color(0xFF00AA55);

  Future<void> renderRoute(List<GeoPoint> points) async {
    final manager = _polylineManager;
    if (manager == null) return;
    await manager.deleteAll();
    await manager.create(
      mapbox.PolylineAnnotationOptions(
        geometry: mapbox.LineString(
          coordinates: [
            for (final point in points)
              mapbox.Position(point.longitude, point.latitude),
          ],
        ),
        // The web's `--accent-green` (#0a5) at weight 5, opacity 0.9. Note
        // the Live Traffic layer paints low-congestion roads a similar
        // green (#2ECC71), so with traffic on, a route along a clear road
        // can blend into it.
        lineColor: _routeGreen.toARGB32(),
        lineWidth: 5,
        lineOpacity: 0.9,
      ),
    );
  }

  Future<void> clearRoute() async => _polylineManager?.deleteAll();

  Future<void> clearIsochroneAndRoute() async {
    await _polygonManager?.deleteAll();
    await _polylineManager?.deleteAll();
  }

  /// Renders (or clears, when [ring] is null) the Lagos state boundary as
  /// an outline — a plain [PolylineAnnotationOptions] rather than a filled
  /// [PolygonAnnotationOptions], since a fill would obscure everything
  /// inside it. Mapbox's simple annotation API has no dash-array support
  /// (only `fill-outline-color` does, and that's a fixed 1px line with no
  /// styling control), so this is a solid line rather than dashed.
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
        lineColor: AppColors.boundary.toARGB32(),
        lineWidth: 2,
      ),
    );
  }
}
