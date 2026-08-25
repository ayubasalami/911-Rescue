import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/geo_point.dart';
import '../../../data/repositories/location_repository.dart';
import '../../get_help/widgets/get_help_sheet.dart';
import '../view_model/home_map_view_model.dart';
import '../widgets/facility_filter_row.dart';
import '../widgets/facility_summary_sheet.dart';
import '../widgets/home_map_header.dart';
import '../widgets/map_control_button.dart';
import '../widgets/your_location_card.dart';

int _categoryColor(FacilityCategory category) => switch (category) {
      FacilityCategory.health => 0xFFD9004C,
      FacilityCategory.police => 0xFF0077FF,
      FacilityCategory.fire => 0xFFF59E0B,
      FacilityCategory.roadSafety => 0xFF9333EA,
      FacilityCategory.other => 0xFF22C55E,
    };

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

// mapbox_maps_flutter renders a native platform view that flutter_test can't
// host, so widget tests fall back to a static placeholder here.
bool get _canRenderRealMap => !Platform.environment.containsKey('FLUTTER_TEST');

class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key});

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  String _selectedFilter = facilityFilters.first;
  mapbox.MapboxMap? _mapboxMap;
  mapbox.CircleAnnotationManager? _circleAnnotationManager;
  List<Facility> _lastRenderedFacilities = const [];
  final Map<String, Facility> _annotationFacilities = {};
  bool _showLocationCard = false;
  TransportMode _selectedTransportMode = TransportMode.driving;

  void _flyTo(GeoPoint point) {
    _mapboxMap?.flyTo(
      mapbox.CameraOptions(center: _mapboxPoint(point), zoom: 12),
      mapbox.MapAnimationOptions(duration: 800),
    );
  }

  void _resetToDefaultView() => _flyTo(defaultMapCenter);

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
    _flyTo(point);
    if (mounted) setState(() => _showLocationCard = true);
  }

  void _analyzeAccess() {
    // Accessibility Analyzer (commute mode + time-threshold routing) isn't
    // built yet on mobile — this mirrors the web feature as a placeholder.
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Accessibility Analyzer is coming soon.')));
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

  Future<void> _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    final manager = await mapboxMap.annotations.createCircleAnnotationManager();
    _circleAnnotationManager = manager;
    manager.tapEvents(
      onTap: (annotation) {
        final facility = _annotationFacilities[annotation.id];
        if (facility != null) _openFacilitySheet(facility);
      },
    );
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
          circleColor: _categoryColor(facility.category),
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
              child: Stack(
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
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Column(
                      children: [
                        MapControlButton(icon: Icons.my_location, onTap: _recenterOnUser),
                        const SizedBox(height: 8),
                        MapControlButton(icon: Icons.home, onTap: _resetToDefaultView),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.extended(
                      backgroundColor: AppColors.danger,
                      onPressed: _openGetHelpSheet,
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('SOS'),
                    ),
                  ),
                  if (_showLocationCard)
                    Align(
                      alignment: Alignment.center,
                      child: FractionalTranslation(
                        translation: const Offset(0, -0.5),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: SizedBox(
                            width: 260,
                            child: YourLocationCard(
                              selectedMode: _selectedTransportMode,
                              onModeSelected: (mode) => setState(() => _selectedTransportMode = mode),
                              onAnalyzeAccess: _analyzeAccess,
                              onGetHelpFast: () {
                                setState(() => _showLocationCard = false);
                                _openGetHelpSheet();
                              },
                              onClose: () => setState(() => _showLocationCard = false),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
