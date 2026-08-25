import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/geo_point.dart';
import '../../../data/repositories/access_analysis_repository.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../data/services/access_analysis_service.dart';
import '../../get_help/widgets/get_help_sheet.dart';
import '../view_model/home_map_view_model.dart';
import '../widgets/access_analysis_sheet.dart';
import '../widgets/access_origin_popup.dart';
import '../widgets/change_commute_mode_card.dart';
import '../widgets/facility_filter_row.dart';
import '../widgets/facility_popup_card.dart';
import '../widgets/facility_summary_sheet.dart';
import '../widgets/home_map_header.dart';
import '../widgets/map_control_button.dart';
import '../widgets/map_legend.dart';
import '../widgets/turn_by_turn_sheet.dart';
import '../widgets/view_results_button.dart';

String _locationStatusMessage(LocationAccessStatus status) => switch (status) {
      LocationAccessStatus.granted => '',
      LocationAccessStatus.denied => 'Location access denied — showing Lagos by default.',
      LocationAccessStatus.deniedForever =>
        'Location permanently denied — enable it in Settings to see nearby facilities.',
      LocationAccessStatus.serviceDisabled => 'Turn on location services to see nearby facilities.',
      LocationAccessStatus.timedOut => 'Couldn\'t get your location in time — showing Lagos by default.',
    };

mapbox.Point _mapboxPoint(GeoPoint point) =>
    mapbox.Point(coordinates: mapbox.Position(point.longitude, point.latitude));

int _colorForBandMinutes(int minutes) =>
    TimeBand.bands.firstWhere((band) => band.maxMinutes == minutes, orElse: () => TimeBand.bands.last).color;

// mapbox_maps_flutter renders a native platform view that flutter_test can't
// host, so widget tests fall back to a static placeholder here.
bool get _canRenderRealMap => !Platform.environment.containsKey('FLUTTER_TEST');

/// The popup shown for "Your Location" or a dropped pin, anchored to a
/// specific point on screen.
class _OriginPopup {
  const _OriginPopup({
    required this.point,
    required this.anchor,
    required this.title,
    required this.analyzeLabel,
    this.followsUser = false,
  });

  final GeoPoint point;
  final Offset anchor;
  final String title;
  final String analyzeLabel;

  /// Whether [point] is the user's live location, rather than a dropped
  /// pin — determines whether routes from here should track a fresh GPS
  /// fix or stay anchored to the point that was analyzed.
  final bool followsUser;
}

class _FacilityPopup {
  const _FacilityPopup({required this.facility, required this.anchor});

  final Facility facility;
  final Offset anchor;
}

class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key});

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  String _selectedFilter = facilityFilters.first;
  mapbox.MapboxMap? _mapboxMap;
  mapbox.CircleAnnotationManager? _circleAnnotationManager;
  mapbox.PolygonAnnotationManager? _polygonAnnotationManager;
  mapbox.PolylineAnnotationManager? _polylineAnnotationManager;
  List<Facility> _lastRenderedFacilities = const [];
  final Map<String, Facility> _annotationFacilities = {};
  TransportMode _selectedTransportMode = TransportMode.driving;
  _OriginPopup? _originPopup;
  _FacilityPopup? _facilityPopup;
  bool _showLegend = true;
  AccessAnalysisResult? _activeAnalysis;
  GeoPoint? _activeAnalysisOrigin;
  bool _activeAnalysisFollowsUser = false;
  bool _showAnalysisSheet = false;
  bool _showChangeModeCard = true;

  Future<void> _flyTo(GeoPoint point) {
    return _mapboxMap?.flyTo(
          mapbox.CameraOptions(center: _mapboxPoint(point), zoom: 12),
          mapbox.MapAnimationOptions(duration: 800),
        ) ??
        Future.value();
  }

  void _resetToDefaultView() => _flyTo(defaultMapCenter);

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  void _toggleLegend() => setState(() => _showLegend = !_showLegend);

  Future<void> _recenterOnUser() async {
    final result = await ref.read(locationRepositoryProvider).currentPosition();
    final point = result.position;
    if (point == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_locationStatusMessage(result.status))));
      }
      return;
    }
    await _flyTo(point);
    final mapboxMap = _mapboxMap;
    if (!mounted || mapboxMap == null) return;
    final pixel = await mapboxMap.pixelForCoordinate(_mapboxPoint(point));
    if (!mounted) return;
    setState(() {
      _facilityPopup = null;
      _originPopup = _OriginPopup(
        point: point,
        anchor: Offset(pixel.x, pixel.y),
        title: 'Your Location',
        analyzeLabel: 'Analyze Access',
        followsUser: true,
      );
    });
  }

  void _onMapTapped(mapbox.MapContentGestureContext context) {
    final coordinates = context.point.coordinates;
    final point = GeoPoint(latitude: coordinates.lat.toDouble(), longitude: coordinates.lng.toDouble());
    unawaited(_showDroppedPinPopup(point));
  }

  /// Centers the camera on [point] before anchoring the popup there, so it
  /// always has room to render fully inside the map area and never ends up
  /// stuck behind the app bar.
  Future<void> _showDroppedPinPopup(GeoPoint point) async {
    await _flyTo(point);
    final mapboxMap = _mapboxMap;
    if (!mounted || mapboxMap == null) return;
    final pixel = await mapboxMap.pixelForCoordinate(_mapboxPoint(point));
    if (!mounted) return;
    setState(() {
      _facilityPopup = null;
      _originPopup = _OriginPopup(
        point: point,
        anchor: Offset(pixel.x, pixel.y),
        title: '📍 Dropped Pin',
        analyzeLabel: 'Analyze Access Here',
      );
    });
  }

  Future<void> _onFacilityTapped(mapbox.CircleAnnotation annotation) async {
    final facility = _annotationFacilities[annotation.id];
    final mapboxMap = _mapboxMap;
    if (facility == null || mapboxMap == null) return;
    final point = GeoPoint(latitude: facility.latitude, longitude: facility.longitude);
    await _flyTo(point);
    if (!mounted) return;
    final pixel = await mapboxMap.pixelForCoordinate(_mapboxPoint(point));
    if (!mounted) return;
    setState(() {
      _originPopup = null;
      _facilityPopup = _FacilityPopup(facility: facility, anchor: Offset(pixel.x, pixel.y));
    });
  }

  void _openGetHelpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => GetHelpSheet(onDismiss: () => Navigator.of(sheetContext).pop()),
    );
  }

  void _openFacilitySheet(Facility facility) {
    showModalBottomSheet(
      context: context,
      builder: (_) => FacilitySummarySheet(facility: facility),
    );
  }

  void _viewFacilityInfo(Facility facility) {
    setState(() => _facilityPopup = null);
    _openFacilitySheet(facility);
  }

  void _saveFacility() {
    setState(() => _facilityPopup = null);
    _showComingSoon('Saving facilities');
  }

  Future<void> _getDirectionsToFacility(Facility facility) async {
    setState(() => _facilityPopup = null);
    final locationResult = await ref.read(locationRepositoryProvider).currentPosition();
    final origin = locationResult.position;
    if (origin == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_locationStatusMessage(locationResult.status))));
      }
      return;
    }
    await _getDirectionsTo(origin, GeoPoint(latitude: facility.latitude, longitude: facility.longitude));
  }

  Future<void> _renderIsochrone(List<IsochroneRing> rings) async {
    final manager = _polygonAnnotationManager;
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

  Future<void> _renderRoute(List<GeoPoint> points) async {
    final manager = _polylineAnnotationManager;
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

  Future<void> _clearIsochroneAndRoute() async {
    await _polygonAnnotationManager?.deleteAll();
    await _polylineAnnotationManager?.deleteAll();
  }

  /// Runs (or re-runs, on a mode change) the analysis for [origin]. Leaving
  /// an analysis active and only closing its sheet — via [_dismissAnalysisSheet]
  /// — must not cancel it; only [_cancelAnalysis] does that.
  Future<void> _runAnalysis(GeoPoint origin, {bool openSheet = true, bool followsUser = false}) async {
    setState(() {
      _originPopup = null;
      _facilityPopup = null;
    });

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ));

    late final AccessAnalysisResult result;
    try {
      result = await ref
          .read(accessAnalysisRepositoryProvider)
          .analyze(origin: origin, mode: _selectedTransportMode);
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not run accessibility analysis: $error')));
      return;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    setState(() {
      _activeAnalysis = result;
      _activeAnalysisOrigin = origin;
      _activeAnalysisFollowsUser = followsUser;
      _showChangeModeCard = true;
      if (openSheet) _showAnalysisSheet = true;
    });
    await _renderIsochrone(result.isochroneRings);
  }

  void _dismissChangeModeCard() => setState(() => _showChangeModeCard = false);

  void _changeCommuteMode(TransportMode mode) {
    setState(() => _selectedTransportMode = mode);
    final origin = _activeAnalysisOrigin;
    if (origin != null) {
      _runAnalysis(origin, openSheet: false, followsUser: _activeAnalysisFollowsUser);
    }
  }

  /// The point routes/directions should start from. For an analysis that
  /// followed "Your Location," this re-fetches a fresh GPS position instead
  /// of reusing the point captured when Analyze Access was tapped — that
  /// captured point goes stale relative to the live location puck the
  /// longer the analysis stays open.
  Future<GeoPoint?> _resolveRouteOrigin() async {
    if (!_activeAnalysisFollowsUser) return _activeAnalysisOrigin;
    final result = await ref.read(locationRepositoryProvider).currentPosition();
    return result.position ?? _activeAnalysisOrigin;
  }

  void _dismissAnalysisSheet() => setState(() => _showAnalysisSheet = false);

  void _reopenAnalysisSheet() => setState(() => _showAnalysisSheet = true);

  Future<void> _cancelAnalysis() async {
    setState(() {
      _activeAnalysis = null;
      _activeAnalysisOrigin = null;
      _activeAnalysisFollowsUser = false;
      _showAnalysisSheet = false;
    });
    await _clearIsochroneAndRoute();
  }

  Future<void> _mapRouteTo(GeoPoint origin, GeoPoint destination) async {
    try {
      final route = await ref
          .read(accessAnalysisServiceProvider)
          .fetchRoute(origin: origin, destination: destination, mode: _selectedTransportMode);
      await _renderRoute(route.points);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load route: $error')));
      }
    }
  }

  Future<void> _getDirectionsTo(GeoPoint origin, GeoPoint destination) async {
    try {
      final route = await ref
          .read(accessAnalysisServiceProvider)
          .fetchRoute(origin: origin, destination: destination, mode: _selectedTransportMode);
      await _renderRoute(route.points);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        barrierColor: Colors.black26,
        builder: (_) => TurnByTurnSheet(steps: route.steps),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load directions: $error')));
      }
    }
  }

  Future<void> _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _polygonAnnotationManager = await mapboxMap.annotations.createPolygonAnnotationManager();

    final circleManager = await mapboxMap.annotations.createCircleAnnotationManager();
    _circleAnnotationManager = circleManager;
    circleManager.tapEvents(onTap: _onFacilityTapped);

    _polylineAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager();

    await mapboxMap.location.updateSettings(
      mapbox.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: AppColors.primary.toARGB32(),
        puckBearingEnabled: true,
        showAccuracyRing: true,
        accuracyRingColor: AppColors.primary.withValues(alpha: 0.15).toARGB32(),
        accuracyRingBorderColor: AppColors.primary.withValues(alpha: 0.3).toARGB32(),
      ),
    );
    await _syncFacilityPins(ref.read(homeMapViewModelProvider).value?.facilities ?? const []);
  }

  Future<void> _syncFacilityPins(List<Facility> facilities) async {
    final manager = _circleAnnotationManager;
    if (manager == null || identical(facilities, _lastRenderedFacilities)) return;
    _lastRenderedFacilities = facilities;

    await manager.deleteAll();
    _annotationFacilities.clear();
    final created = await manager.createMulti([
      for (final facility in facilities)
        mapbox.CircleAnnotationOptions(
          geometry: mapbox.Point(coordinates: mapbox.Position(facility.longitude, facility.latitude)),
          circleColor: facility.category.legendColor.toARGB32(),
          circleRadius: 8,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 2,
        ),
    ]);
    for (final (index, annotation) in created.indexed) {
      if (annotation != null) _annotationFacilities[annotation.id] = facilities[index];
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeMapAsync = ref.watch(homeMapViewModelProvider);
    homeMapAsync.whenData((state) => _syncFacilityPins(state.facilities));

    ref.listen(homeMapViewModelProvider, (previous, next) {
      final status = next.value?.locationStatus;
      if (status != null &&
          status != LocationAccessStatus.granted &&
          previous?.value?.locationStatus != status) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_locationStatusMessage(status))));
      }
    });

    final showFloatingAnalysisControls = _activeAnalysis != null && !_showAnalysisSheet;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const HomeMapHeader(),
            FacilityFilterRow(
              selected: _selectedFilter,
              onSelected: (filter) => setState(() => _selectedFilter = filter),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: homeMapAsync.maybeWhen(
                          data: (state) => _canRenderRealMap
                              ? mapbox.MapWidget(
                                  styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
                                  viewport: mapbox.CameraViewportState(
                                    center: _mapboxPoint(state.center),
                                    zoom: 12,
                                  ),
                                  onMapCreated: _onMapCreated,
                                  // ignore: deprecated_member_use
                                  onTapListener: _onMapTapped,
                                )
                              : Container(color: AppColors.backgroundCanvas),
                          orElse: () => Container(color: AppColors.backgroundCanvas),
                        ),
                      ),
                      if (homeMapAsync.isLoading)
                        const Positioned.fill(child: Center(child: CircularProgressIndicator())),
                      if (homeMapAsync.hasError)
                        Positioned.fill(
                          child: Center(child: Text('Failed to load facilities: ${homeMapAsync.error}')),
                        ),
                      if (_showLegend) const Positioned(left: 16, bottom: 16, child: MapLegend()),
                      Positioned(
                        right: 16,
                        top: 16,
                        child: Column(
                          children: [
                            MapControlButton(icon: Icons.my_location, onTap: _recenterOnUser),
                            const SizedBox(height: 8),
                            MapControlButton(icon: Icons.home, onTap: _resetToDefaultView),
                            const SizedBox(height: 8),
                            MapControlButton(
                              icon: Icons.search,
                              onTap: () => _showComingSoon('Search'),
                            ),
                            const SizedBox(height: 8),
                            MapControlButton(
                              icon: Icons.near_me,
                              onTap: () => _showComingSoon('Route planner'),
                            ),
                            const SizedBox(height: 8),
                            MapControlButton(icon: Icons.list, active: _showLegend, onTap: _toggleLegend),
                            const SizedBox(height: 8),
                            MapControlButton(
                              icon: Icons.delete_outline,
                              iconColor: AppColors.danger,
                              onTap: _cancelAnalysis,
                            ),
                            const SizedBox(height: 8),
                            MapControlButton(
                              icon: Icons.traffic,
                              onTap: () => _showComingSoon('Live traffic'),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton(
                          backgroundColor: AppColors.danger,
                          onPressed: _openGetHelpSheet,
                          child: const Text('🚨', style: TextStyle(fontSize: 26)),
                        ),
                      ),
                      if (showFloatingAnalysisControls)
                        Positioned(
                          right: 16,
                          bottom: 88,
                          width: 220,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_showChangeModeCard) ...[
                                ChangeCommuteModeCard(
                                  selectedMode: _selectedTransportMode,
                                  onModeSelected: _changeCommuteMode,
                                  onClose: _dismissChangeModeCard,
                                ),
                                const SizedBox(height: 8),
                              ],
                              ViewResultsButton(onTap: _reopenAnalysisSheet),
                            ],
                          ),
                        ),
                      if (_originPopup != null)
                        _AnchoredPopup(
                          anchor: _originPopup!.anchor,
                          maxWidth: constraints.maxWidth,
                          child: AccessOriginPopup(
                            title: _originPopup!.title,
                            selectedMode: _selectedTransportMode,
                            onModeSelected: (mode) => setState(() => _selectedTransportMode = mode),
                            analyzeLabel: _originPopup!.analyzeLabel,
                            onAnalyzeAccess: () =>
                                _runAnalysis(_originPopup!.point, followsUser: _originPopup!.followsUser),
                            onGetHelpFast: () {
                              setState(() => _originPopup = null);
                              _openGetHelpSheet();
                            },
                            onClose: () => setState(() => _originPopup = null),
                          ),
                        ),
                      if (_facilityPopup != null)
                        _AnchoredPopup(
                          anchor: _facilityPopup!.anchor,
                          maxWidth: constraints.maxWidth,
                          child: FacilityPopupCard(
                            facility: _facilityPopup!.facility,
                            onViewInfo: () => _viewFacilityInfo(_facilityPopup!.facility),
                            onAnalyzeAccess: () => _runAnalysis(
                              GeoPoint(
                                latitude: _facilityPopup!.facility.latitude,
                                longitude: _facilityPopup!.facility.longitude,
                              ),
                            ),
                            onGetDirections: () => _getDirectionsToFacility(_facilityPopup!.facility),
                            onSaveFacility: _saveFacility,
                            onClose: () => setState(() => _facilityPopup = null),
                          ),
                        ),
                      if (_showAnalysisSheet && _activeAnalysis != null)
                        Positioned.fill(
                          child: AccessAnalysisSheet(
                            result: _activeAnalysis!,
                            onMapRoute: (destination) async {
                              final origin = await _resolveRouteOrigin();
                              if (origin != null) await _mapRouteTo(origin, destination);
                            },
                            onDirections: (destination) async {
                              final origin = await _resolveRouteOrigin();
                              if (origin != null) await _getDirectionsTo(origin, destination);
                            },
                            onClose: _dismissAnalysisSheet,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Positions [child] so its bottom edge sits just above [anchor] (a point in
/// the map's local coordinate space), horizontally centered on it and
/// clamped within [maxWidth].
class _AnchoredPopup extends StatelessWidget {
  const _AnchoredPopup({required this.anchor, required this.maxWidth, required this.child});

  final Offset anchor;
  final double maxWidth;
  final Widget child;

  static const _popupWidth = 260.0;

  /// The popup's content can run to roughly this tall (mode picker + two
  /// action buttons); keeping the anchor at least this far from the map
  /// area's top edge guarantees the popup always renders fully inside the
  /// map, never reaching up behind the app bar, regardless of how close to
  /// the top of the visible map the anchor point itself ends up.
  static const _minAnchorY = 240.0;

  @override
  Widget build(BuildContext context) {
    final maxLeft = maxWidth - _popupWidth - 8 > 8 ? maxWidth - _popupWidth - 8 : 8.0;
    final left = (anchor.dx - _popupWidth / 2).clamp(8.0, maxLeft);
    final top = anchor.dy < _minAnchorY ? _minAnchorY : anchor.dy;
    return Positioned(
      left: left,
      top: top,
      child: FractionalTranslation(
        translation: const Offset(0, -1),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SizedBox(width: _popupWidth, child: child),
        ),
      ),
    );
  }
}
