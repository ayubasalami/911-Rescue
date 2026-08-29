import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/geo_point.dart';
import '../widgets/map_legend.dart';

mapbox.Point mapboxPointFrom(GeoPoint point) =>
    mapbox.Point(coordinates: mapbox.Position(point.longitude, point.latitude));

int _colorForBandMinutes(int minutes) => TimeBand.bands
    .firstWhere((band) => band.maxMinutes == minutes, orElse: () => TimeBand.bands.last)
    .color;

/// Rasterizes a facility category's legend glyph (colored circle + white
/// icon) into a PNG, so map pins actually match the legend instead of
/// being plain colored dots.
Future<Uint8List> _renderCategoryMarker(FacilityCategory category) async {
  const size = 96.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
  const center = Offset(size / 2, size / 2);
  const radius = size / 2 - 4;

  canvas.drawCircle(center, radius, Paint()..color = Colors.white);
  canvas.drawCircle(center, radius - 4, Paint()..color = category.legendColor);

  final icon = category.legendIcon;
  final textPainter = TextPainter(textDirection: TextDirection.ltr)
    ..text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.48,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    )
    ..layout();
  textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// Rasterizes a map-pin glyph for the current-location puck, replacing
/// Mapbox's default plain dot with an actual location pin icon.
Future<Uint8List> _renderLocationPinImage() async {
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
  textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
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

  List<Facility> _lastSourceFacilities = const [];
  FacilityCategory? _lastAppliedFilter;
  final Map<String, Facility> _annotationFacilities = {};
  final Map<FacilityCategory, Uint8List> _markerImages = {};

  GeoPoint? _lastDroppedPin;
  Uint8List? _pinDropImage;

  static const _trafficSourceId = 'traffic-source';
  static const _trafficLayerId = 'traffic-layer';
  bool _trafficLayerAdded = false;
  bool? _lastTrafficVisible;

  Facility? facilityForAnnotation(String annotationId) => _annotationFacilities[annotationId];

  Future<void> onMapCreated(
    mapbox.MapboxMap mapboxMap, {
    required void Function(mapbox.PointAnnotation) onFacilityTap,
  }) async {
    _map = mapboxMap;
    _polygonManager = await mapboxMap.annotations.createPolygonAnnotationManager();

    final facilityManager = await mapboxMap.annotations.createPointAnnotationManager();
    _facilityManager = facilityManager;
    facilityManager.tapEvents(onTap: onFacilityTap);

    _originManager = await mapboxMap.annotations.createPointAnnotationManager();

    _polylineManager = await mapboxMap.annotations.createPolylineAnnotationManager();

    await mapboxMap.location.updateSettings(
      mapbox.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: false,
        locationPuck: mapbox.LocationPuck(
          locationPuck2D: mapbox.LocationPuck2D(topImage: await _renderLocationPinImage()),
        ),
      ),
    );
  }

  Future<void> flyTo(GeoPoint point) {
    return _map?.flyTo(
          mapbox.CameraOptions(center: mapboxPointFrom(point), zoom: 12),
          mapbox.MapAnimationOptions(duration: 800),
        ) ??
        Future.value();
  }

  /// The on-screen pixel for [point], or null if the map isn't ready yet.
  Future<Offset?> pixelForCoordinate(GeoPoint point) async {
    final map = _map;
    if (map == null) return null;
    final pixel = await map.pixelForCoordinate(mapboxPointFrom(point));
    return Offset(pixel.x, pixel.y);
  }

  Future<Uint8List> _markerImageFor(FacilityCategory category) async {
    return _markerImages[category] ??= await _renderCategoryMarker(category);
  }

  Future<void> syncFacilityPins(List<Facility> facilities, FacilityCategory? filter) async {
    final manager = _facilityManager;
    if (manager == null) return;
    if (identical(facilities, _lastSourceFacilities) && _lastAppliedFilter == filter) {
      return;
    }
    _lastSourceFacilities = facilities;
    _lastAppliedFilter = filter;

    final visible = [
      for (final facility in facilities)
        if (filter == null || facility.category == filter) facility,
    ];

    await manager.deleteAll();
    _annotationFacilities.clear();
    final created = await manager.createMulti([
      for (final facility in visible)
        mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(coordinates: mapbox.Position(facility.longitude, facility.latitude)),
          image: await _markerImageFor(facility.category),
          iconSize: 0.80,
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

    await manager.create(
      mapbox.PointAnnotationOptions(
        geometry: mapboxPointFrom(point),
        image: await _pinDropMarkerImage(),
        iconSize: 0.6,
        iconAnchor: mapbox.IconAnchor.BOTTOM,
      ),
    );
  }

  Future<Uint8List> _pinDropMarkerImage() async {
    return _pinDropImage ??= await _renderLocationPinImage();
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
        mapbox.VectorSource(id: _trafficSourceId, url: 'mapbox://mapbox.mapbox-traffic-v1'),
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
            'low', '#2ECC71',
            'moderate', '#F1C40F',
            'heavy', '#E67E22',
            'severe', '#C0392B',
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
              [for (final point in ring.points) mapbox.Position(point.longitude, point.latitude)],
            ],
          ),
          fillColor: _colorForBandMinutes(ring.minutes),
          fillOpacity: 0.35,
        ),
    ]);
  }

  Future<void> renderRoute(List<GeoPoint> points) async {
    final manager = _polylineManager;
    if (manager == null) return;
    await manager.deleteAll();
    await manager.create(
      mapbox.PolylineAnnotationOptions(
        geometry: mapbox.LineString(
          coordinates: [for (final point in points) mapbox.Position(point.longitude, point.latitude)],
        ),
        lineColor: AppColors.success.toARGB32(),
        lineWidth: 4,
      ),
    );
  }

  Future<void> clearIsochroneAndRoute() async {
    await _polygonManager?.deleteAll();
    await _polylineManager?.deleteAll();
  }
}
