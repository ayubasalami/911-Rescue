import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/facility.dart';
import '../../get_help/widgets/get_help_sheet.dart';
import '../view_model/home_map_view_model.dart';
import '../widgets/facility_filter_row.dart';
import '../widgets/facility_summary_sheet.dart';
import '../widgets/home_map_header.dart';
import '../widgets/map_control_button.dart';

final _initialCenter = mapbox.Point(coordinates: mapbox.Position(3.3792, 6.5244));

int _categoryColor(FacilityCategory category) => switch (category) {
      FacilityCategory.health => 0xFFD9004C,
      FacilityCategory.police => 0xFF0077FF,
      FacilityCategory.fire => 0xFFF59E0B,
      FacilityCategory.roadSafety => 0xFF9333EA,
      FacilityCategory.other => 0xFF22C55E,
    };

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

  void _recenter() {
    _mapboxMap?.flyTo(
      mapbox.CameraOptions(center: _initialCenter, zoom: 12),
      mapbox.MapAnimationOptions(duration: 800),
    );
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
    await _syncFacilityPins(ref.read(homeMapViewModelProvider).value ?? const []);
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
    final facilitiesAsync = ref.watch(homeMapViewModelProvider);
    facilitiesAsync.whenData(_syncFacilityPins);

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
                    child: _canRenderRealMap
                        ? mapbox.MapWidget(
                            styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
                            viewport: mapbox.CameraViewportState(center: _initialCenter, zoom: 12),
                            onMapCreated: _onMapCreated,
                          )
                        : Container(color: AppColors.backgroundCanvas),
                  ),
                  if (facilitiesAsync.isLoading)
                    const Positioned.fill(child: Center(child: CircularProgressIndicator())),
                  if (facilitiesAsync.hasError)
                    Positioned.fill(
                      child: Center(child: Text('Failed to load facilities: ${facilitiesAsync.error}')),
                    ),
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Column(
                      children: [
                        MapControlButton(icon: Icons.my_location, onTap: _recenter),
                        const SizedBox(height: 8),
                        MapControlButton(icon: Icons.home, onTap: _recenter),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
