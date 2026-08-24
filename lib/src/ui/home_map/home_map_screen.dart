import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../../core/theme/app_theme.dart';
import '../../data/models/facility.dart';
import '../../routing/app_router.dart';
import '../core/widgets/app_filter_chip.dart';
import '../get_help/get_help_screen.dart';
import 'view_model/home_map_view_model.dart';

const _filters = ['All', 'Health', 'Police', 'Fire'];

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
  String _selectedFilter = _filters.first;
  int _navIndex = 0;
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
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(facility.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(facility.address, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSurface,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    children: [
                      TextSpan(text: '911 ', style: TextStyle(color: AppColors.primary)),
                      TextSpan(text: 'Rescue', style: TextStyle(color: AppColors.success)),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  return AppFilterChip(
                    label: filter,
                    selected: _selectedFilter == filter,
                    onTap: () => setState(() => _selectedFilter = filter),
                  );
                },
              ),
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
                        _MapControlButton(icon: Icons.my_location, onTap: _recenter),
                        const SizedBox(height: 8),
                        _MapControlButton(icon: Icons.home, onTap: _recenter),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (index) {
          setState(() => _navIndex = index);
          switch (index) {
            case 1:
              context.push(AppRoute.triageChat);
            case 2:
              context.push(AppRoute.dashboard);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Triage'),
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
      ),
    );
  }
}
