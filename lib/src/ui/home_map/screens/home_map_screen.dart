import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/geo_point.dart';
import '../../get_help/widgets/get_help_sheet.dart';
import '../../triage_chat/widgets/triage_chat_sheet.dart';
import '../../triage_chat/widgets/triage_entry_sheet.dart';
import '../controllers/map_annotation_controller.dart';
import '../view_model/home_map_view_model.dart';
import '../widgets/access_analysis_sheet.dart';
import '../widgets/access_origin_popup.dart';
import '../widgets/calculating_route_overlay.dart';
import '../widgets/change_commute_mode_card.dart';
import '../widgets/facility_filter_row.dart';
import '../widgets/facility_popup_card.dart';
import '../widgets/facility_summary_sheet.dart';
import '../widgets/go_to_help_card.dart';
import '../widgets/go_to_help_mode_bar.dart';
import '../widgets/home_drawer.dart';
import '../widgets/home_map_header.dart';
import '../widgets/map_control_button.dart';
import '../widgets/map_legend.dart';
import '../widgets/route_active_chip.dart';
import '../widgets/sos_action_menu.dart';
import '../widgets/turn_by_turn_sheet.dart';
import '../widgets/view_results_button.dart';
import '../widgets/zoom_in_hint.dart';

// mapbox_maps_flutter renders a native platform view that flutter_test can't
// host, so widget tests fall back to a static placeholder here.
bool get _canRenderRealMap => !Platform.environment.containsKey('FLUTTER_TEST');

class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key});

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

/// Everything here is view-layer wiring: presenting dialogs/sheets/snackbars
/// (which need `BuildContext`), and driving [MapAnnotationController] (which
/// holds the live Mapbox platform view). All business/app state and
/// orchestration logic lives in [HomeMapViewModel] — see it and
/// [MapAnnotationController] for why the split is drawn there.
class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  final _mapController = MapAnnotationController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// The on-screen anchor for whichever popup is showing (origin or
  /// facility selection, from [HomeMapState]) — a derived pixel position,
  /// not business state, so it stays here rather than in the ViewModel.
  ///
  /// A `ValueNotifier` rather than a plain field + `setState`: this updates
  /// on every camera-change event during a pan/zoom gesture (so the popup
  /// tracks the map like a real annotation would), and routing that through
  /// `setState` would rebuild the entire screen — map, legend, buttons,
  /// filter chips — dozens of times a second. A `ValueListenableBuilder`
  /// around just the popup keeps each update scoped to that small subtree.
  final ValueNotifier<Offset?> _popupAnchor = ValueNotifier(null);
  final ValueNotifier<bool> _pingActive = ValueNotifier(false);

  /// Drives [ZoomInHint] — kept in a `ValueNotifier` for the same reason as
  /// [_popupAnchor]: it changes on nearly every frame during a pinch/pan
  /// gesture, and routing that through `setState` would rebuild the whole
  /// screen instead of just the hint.
  final ValueNotifier<double> _cameraZoom = ValueNotifier(12);

  /// Tracks which side of [_facilityVisibleZoom] the camera was on last, so
  /// [_onCameraChanged] only re-syncs facility markers when that actually
  /// flips rather than on every frame.
  bool _facilitiesWereVisible = false;

  /// Guards against overlapping `pixelForCoordinate` platform-channel calls:
  /// `onCameraChangeListener` fires on nearly every rendered frame during a
  /// gesture, and each call is an async native round-trip — without this,
  /// a drag/pan floods dozens of overlapping in-flight calls per second.
  /// Dropping a redundant call is safe since another camera-change event
  /// (with fresher data) follows almost immediately.
  bool _syncingPopupAnchor = false;

  /// The map's starting camera position, computed once and reused — not
  /// business state, just a cached widget config value. `CameraViewportState`
  /// has no value equality, so a fresh instance built on every `build()`
  /// call is never `==` to the previous one; the plugin treats that as "the
  /// viewport changed" and snaps the camera back to it, discarding wherever
  /// the user has since panned/flown to (e.g. right after dropping a pin).
  mapbox.CameraViewportState? _initialViewport;

  /// Set for exactly one frame when Go to Help's "Send SOS instead" hands
  /// off into [GetHelpSheet] — read by that widget's `initState` to open
  /// straight into "Finding a responder…" instead of its normal
  /// choose-option view, then cleared so a later, unrelated "Get Help Fast"
  /// open doesn't also auto-start a ping.
  FacilityCategory? _pendingSosCategory;

  /// Owned here (not by [HomeDrawer]) so the map's side-button search icon
  /// can request focus on the drawer's search field from outside it.
  final FocusNode _searchFocusNode = FocusNode();

  HomeMapViewModel get _viewModel =>
      ref.read(homeMapViewModelProvider.notifier);

  @override
  void dispose() {
    _popupAnchor.dispose();
    _pingActive.dispose();
    _cameraZoom.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  void _resetToDefaultView() => _mapController.flyTo(defaultMapCenter);

  Future<void> _recenterOnUser() async {
    final point = await _viewModel.recenterOnUser();
    if (point == null || !mounted) return;
    await _mapController.flyTo(point);
    if (!mounted) return;
    final anchor = await _mapController.pixelForCoordinate(point);
    if (!mounted) return;
    _popupAnchor.value = anchor;
  }

  /// The geo-point whichever popup is currently showing is anchored to, if
  /// any — used to keep the popup's on-screen position following the map
  /// as the camera moves, the same way a real map annotation would.
  GeoPoint? _activePopupPoint(HomeMapState? state) {
    final origin = state?.originSelection;
    if (origin != null) return origin.point;
    final facility = state?.selectedFacility;
    if (facility != null) {
      return GeoPoint(
        latitude: facility.latitude,
        longitude: facility.longitude,
      );
    }
    return null;
  }

  /// Fired on nearly every rendered frame during a pan/zoom/rotate gesture —
  /// must stay a stable method reference (not an inline lambda) so it
  /// doesn't look like a new callback to the plugin on every rebuild, which
  /// would re-subscribe the native listener on every single frame.
  void _onCameraChanged(mapbox.CameraChangedEventData event) {
    unawaited(_syncPopupAnchor());
    _cameraZoom.value = event.cameraState.zoom;

    // Only re-sync facility markers when zoom crosses the visibility
    // threshold, not on every frame — syncFacilityPins deletes and
    // recreates every marker, which would be wasteful mid-gesture.
    final nowVisible = event.cameraState.zoom >= _facilityVisibleZoom;
    if (nowVisible != _facilitiesWereVisible) {
      _facilitiesWereVisible = nowVisible;
      final state = ref.read(homeMapViewModelProvider).value;
      unawaited(
        _mapController.syncFacilityPins(
          _facilitiesToRender(state),
          state?.selectedFilter,
        ),
      );
    }
  }

  /// Re-projects the active popup's anchor point to screen pixels on every
  /// camera change (pan/zoom/rotate) — without this, the popup stays fixed
  /// on screen while the map moves underneath it, instead of appearing to
  /// be part of the map like a real annotation.
  Future<void> _syncPopupAnchor() async {
    if (_syncingPopupAnchor) return;
    final point = _activePopupPoint(ref.read(homeMapViewModelProvider).value);
    if (point == null) return;
    _syncingPopupAnchor = true;
    try {
      final anchor = await _mapController.pixelForCoordinate(point);
      if (mounted && anchor != null) _popupAnchor.value = anchor;
    } finally {
      _syncingPopupAnchor = false;
    }
  }

  void _onMapTapped(mapbox.MapContentGestureContext context) {
    final coordinates = context.point.coordinates;
    final point = GeoPoint(
      latitude: coordinates.lat.toDouble(),
      longitude: coordinates.lng.toDouble(),
    );
    unawaited(_selectDroppedPin(point));
  }

  /// Centers the camera on [point] before anchoring the popup there, so it
  /// always has room to render fully inside the map area and never ends up
  /// stuck behind the app bar.
  Future<void> _selectDroppedPin(GeoPoint point) async {
    await _mapController.flyTo(point);
    if (!mounted) return;
    final anchor = await _mapController.pixelForCoordinate(point);
    if (!mounted) return;
    _viewModel.selectOrigin(
      point: point,
      title: '📍 Dropped Pin',
      analyzeLabel: 'Analyze Access Here',
    );
    _popupAnchor.value = anchor;
  }

  Future<void> _onFacilityTapped(mapbox.PointAnnotation annotation) async {
    final facility = _mapController.facilityForAnnotation(annotation.id);
    if (facility == null) return;
    final point = GeoPoint(
      latitude: facility.latitude,
      longitude: facility.longitude,
    );
    await _mapController.flyTo(point);
    if (!mounted) return;
    final anchor = await _mapController.pixelForCoordinate(point);
    if (!mounted) return;
    _viewModel.selectFacility(facility);
    _popupAnchor.value = anchor;
  }

  void _clearPopup() {
    _viewModel.clearPopups();
    _popupAnchor.value = null;
  }

  /// Routes to the nearest [category] facility from the current origin,
  /// then draws the route and zooms out to show it in full — matches the
  /// web platform's Go to Help, confirmed live to auto-pick the closest
  /// facility rather than asking the user to choose one.
  Future<void> _startGoToHelp(FacilityCategory category) async {
    await _viewModel.startGoToHelp(category);
    final state = ref.read(homeMapViewModelProvider).value;
    final origin = state?.goToHelpOrigin;
    final route = state?.goToHelpRoute;
    if (!mounted || origin == null || route == null) return;
    // Mapbox snaps the route's own first point to the nearest road, which
    // can sit a little away from the pin itself and read as the line
    // "overshooting" it — prepending the exact origin keeps the drawn line
    // anchored to the pin.
    await _mapController.renderRoute([origin, ...route.points]);
    if (!mounted) return;
    await _mapController.flyToBounds(route.points);
  }

  Future<void> _changeGoToHelpMode(TransportMode mode) async {
    _viewModel.setSelectedMode(mode);
    await _viewModel.refreshGoToHelpRoute();
    final state = ref.read(homeMapViewModelProvider).value;
    final origin = state?.goToHelpOrigin;
    final route = state?.goToHelpRoute;
    if (!mounted || origin == null || route == null) return;
    await _mapController.renderRoute([origin, ...route.points]);
  }

  Future<void> _closeGoToHelp() async {
    _viewModel.closeGoToHelp();
    await _mapController.clearIsochroneAndRoute();
  }

  /// "Send SOS instead"'s "Who do you need?" confirmation, once a category
  /// is picked — clears the route and hands off into the same Ping for Help
  /// flow the origin popup's "Get Help Fast" card uses, anchored at
  /// wherever Go to Help's origin currently is (live position if tracking,
  /// the dropped pin otherwise).
  Future<void> _confirmSosInstead(FacilityCategory category) async {
    final state = ref.read(homeMapViewModelProvider).value;
    final origin = state?.goToHelpOrigin;
    final followsUser = state?.goToHelpFollowsUser ?? false;
    if (origin == null) return;

    await _mapController.clearIsochroneAndRoute();
    _viewModel.selectOrigin(
      point: origin,
      title: followsUser ? 'Your Location' : '📍 Dropped Pin',
      analyzeLabel: followsUser ? 'Analyze Access' : 'Analyze Access Here',
      followsUser: followsUser,
    );
    _viewModel.openGetHelpFast();
    setState(() => _pendingSosCategory = category);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _pendingSosCategory = null);
    });

    await _mapController.flyTo(origin);
    if (!mounted) return;
    final anchor = await _mapController.pixelForCoordinate(origin);
    if (!mounted) return;
    _popupAnchor.value = anchor;
  }

  /// Begins live GPS tracking for the active route — the web platform's
  /// "Start" — and recenters the camera on the live origin once, rather
  /// than on every subsequent GPS fix (which would repeatedly wrest the
  /// camera away from a user trying to pan/zoom manually).
  Future<void> _startTracking() async {
    await _viewModel.startGoToHelpTracking();
    final origin = ref.read(homeMapViewModelProvider).value?.goToHelpOrigin;
    if (!mounted || origin == null) return;
    await _mapController.flyTo(origin);
  }

  void _viewGoToHelpSteps(List<DirectionsStep> steps) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black26,
      builder: (_) => TurnByTurnSheet(steps: steps),
    );
  }

  Future<void> _call112() async {
    _viewModel.closeSosMenu();
    final uri = Uri(scheme: 'tel', path: '112');
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start a call.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start a call.')),
        );
      }
    }
  }

  void _openTriageEntry() {
    _viewModel.closeSosMenu();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: TriageEntrySheet(
          onCall112: () {
            Navigator.of(dialogContext).pop();
            _call112();
          },
          onReportIncident: () {
            Navigator.of(dialogContext).pop();
            _openTriageChat();
          },
        ),
      ),
    );
  }

  void _openTriageChat() {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: const TriageChatSheet(),
      ),
    );
  }

  void _openFacilitySheet(Facility facility) {
    showModalBottomSheet(
      context: context,
      builder: (_) => FacilitySummarySheet(facility: facility),
    );
  }

  void _viewFacilityInfo(Facility facility) {
    _clearPopup();
    _openFacilitySheet(facility);
  }

  void _saveFacility() {
    _clearPopup();
    _showComingSoon('Saving facilities');
  }

  Future<void> _getDirectionsToFacility(Facility facility) async {
    _clearPopup();
    final origin = await _viewModel.currentUserLocation();
    if (origin == null) return;
    await _getDirectionsTo(
      origin,
      GeoPoint(latitude: facility.latitude, longitude: facility.longitude),
    );
  }

  Future<void> _mapRouteTo(GeoPoint origin, GeoPoint destination) async {
    final route = await _viewModel.fetchRoute(origin, destination);
    if (route != null) await _mapController.renderRoute(route.points);
  }

  Future<void> _getDirectionsTo(GeoPoint origin, GeoPoint destination) async {
    final route = await _viewModel.fetchRoute(origin, destination);
    if (route == null) return;
    await _mapController.renderRoute(route.points);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black26,
      builder: (_) => TurnByTurnSheet(steps: route.steps),
    );
  }

  /// Runs (or re-runs, on a mode change) the analysis for [origin], showing
  /// a blocking loading dialog while it's in flight and rendering the
  /// resulting isochrone polygon on success. Any failure is surfaced by the
  /// [HomeMapState.errorMessage] listener in [build] instead of here.
  Future<void> _runAnalysis(
    GeoPoint origin, {
    bool openSheet = true,
    bool followsUser = false,
  }) async {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );
    await _viewModel.runAnalysis(
      origin,
      openSheet: openSheet,
      followsUser: followsUser,
    );
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    final rings = ref
        .read(homeMapViewModelProvider)
        .value
        ?.activeAnalysis
        ?.isochroneRings;
    if (rings != null) await _mapController.renderIsochrone(rings);
  }

  Future<void> _changeCommuteMode(TransportMode mode) async {
    await _viewModel.changeCommuteMode(mode);
    final rings = ref
        .read(homeMapViewModelProvider)
        .value
        ?.activeAnalysis
        ?.isochroneRings;
    if (rings != null) await _mapController.renderIsochrone(rings);
  }

  Future<void> _cancelAnalysis() async {
    await _viewModel.cancelAnalysis();
    await _mapController.clearIsochroneAndRoute();
  }

  /// The facility list to actually render — empty when the drawer's
  /// "Emergency Facilities" layer toggle is off, independent of [selectedFilter].
  List<Facility> _visibleFacilities(HomeMapState? state) =>
      (state?.showEmergencyFacilities ?? true)
      ? (state?.facilities ?? const [])
      : const [];

  /// Below this zoom, [_facilitiesToRender] returns nothing and
  /// [ZoomInHint] shows instead — matches the web platform's own "Zoom in
  /// to see facilities" behavior (confirmed live), which exists because
  /// rendering all ~2,900 Lagos-wide facilities at once is an unreadable
  /// wall of overlapping pins rather than a usable map.
  static const _facilityVisibleZoom = 13.0;

  /// [_visibleFacilities], additionally gated by zoom — a *separate* method
  /// from it (rather than folding the check in there) since the zoom-in
  /// hint needs to know "would there be facilities to show here if zoomed
  /// in enough", which `_visibleFacilities` alone still answers.
  List<Facility> _facilitiesToRender(HomeMapState? state) =>
      _cameraZoom.value >= _facilityVisibleZoom
      ? _visibleFacilities(state)
      : const [];

  /// The point to show a static map marker for — null for "Your Location"
  /// (which already has its own live location puck) or when there's no
  /// origin selection at all, UNLESS a Go to Help route is active: the
  /// route line is drawn once, from a frozen coordinate, but the native GPS
  /// puck keeps live-updating from CoreLocation independently of it — so
  /// without a static marker pinned at the same frozen coordinate, the puck
  /// visibly drifts away from where the line actually starts. A dropped pin
  /// never has this problem since it already is a static marker.
  GeoPoint? _droppedPinPoint(HomeMapState? state) {
    final goToHelpOrigin = state?.goToHelpOrigin;
    if (goToHelpOrigin != null) return goToHelpOrigin;
    final selection = state?.originSelection;
    if (selection == null || selection.followsUser) return null;
    return selection.point;
  }

  Future<void> _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    await _mapController.onMapCreated(
      mapboxMap,
      onFacilityTap: _onFacilityTapped,
    );
    final state = ref.read(homeMapViewModelProvider).value;
    await _mapController.syncFacilityPins(
      _facilitiesToRender(state),
      state?.selectedFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeMapAsync = ref.watch(homeMapViewModelProvider);
    final state = homeMapAsync.value;
    if (state != null) {
      unawaited(
        _mapController.syncFacilityPins(
          _facilitiesToRender(state),
          state.selectedFilter,
        ),
      );
      unawaited(_mapController.syncDroppedPin(_droppedPinPoint(state)));
      unawaited(_mapController.setTrafficVisible(state.showLiveTraffic));
      unawaited(
        _mapController.syncBoundary(
          state.showLagosBoundary ? state.lagosBoundary : null,
        ),
      );
      // While tracking, the origin/route keep changing from the live GPS
      // stream (see HomeMapViewModel._onTrackedPosition) rather than from
      // an explicit screen action, so the line has to be kept in sync here
      // reactively instead of imperatively like _startGoToHelp does.
      if (state.goToHelpTracking) {
        final origin = state.goToHelpOrigin;
        final route = state.goToHelpRoute;
        if (origin != null && route != null) {
          unawaited(_mapController.renderRoute([origin, ...route.points]));
        }
      }
    }

    ref.listen(homeMapViewModelProvider, (previous, next) {
      final message = next.value?.errorMessage;
      if (message != null &&
          message.isNotEmpty &&
          previous?.value?.errorMessage != message) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        _viewModel.clearErrorMessage();
      }
    });

    final showFloatingAnalysisControls =
        state?.activeAnalysis != null && state?.showAnalysisSheet != true;

    // The map itself is full-bleed behind the status bar/notch on purpose —
    // only the floating controls need to stay clear of it, so they get
    // nudged down/up by the system inset instead of the whole body being
    // wrapped in a SafeArea (which would inset the map too).
    final viewPadding = MediaQuery.paddingOf(context);
    final topInset = viewPadding.top;
    final bottomInset = viewPadding.bottom;

    return Scaffold(
      key: _scaffoldKey,
      drawer: HomeDrawer(
        onUseCurrentLocation: _recenterOnUser,
        onClearAnalysis: _cancelAnalysis,
        searchFocusNode: _searchFocusNode,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: homeMapAsync.maybeWhen(
              data: (s) => _canRenderRealMap
                  ? mapbox.MapWidget(
                      styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
                      viewport: _initialViewport ??= mapbox.CameraViewportState(
                        center: mapboxPointFrom(s.center),
                        zoom: 12,
                      ),
                      onMapCreated: _onMapCreated,
                      // ignore: deprecated_member_use
                      onTapListener: _onMapTapped,
                      onCameraChangeListener: _onCameraChanged,
                    )
                  : Container(color: AppColors.backgroundCanvas),
              orElse: () => Container(color: AppColors.backgroundCanvas),
            ),
          ),
          if (homeMapAsync.isLoading)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator()),
            ),
          if (homeMapAsync.hasError)
            Positioned.fill(
              child: Center(
                child: Text('Failed to load facilities: ${homeMapAsync.error}'),
              ),
            ),
          if (state?.showLegend ?? true)
            Positioned(
              left: 16,
              bottom: 16 + bottomInset,
              child: const MapLegend(),
            ),
          Positioned(
            top: 6 + topInset,
            left: 16,
            child: MapControlButton(
              icon: Icons.menu,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
          Positioned(
            top: 6 + topInset,
            left: 68,
            right: 16,
            child: const HomeMapHeader(),
          ),
          Positioned(
            top: 58 + topInset,
            left: 0,
            right: 0,
            child: FacilityFilterRow(
              selected: state?.selectedFilter,
              onSelected: _viewModel.selectFilter,
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _cameraZoom,
            builder: (context, zoom, _) {
              if (zoom >= _facilityVisibleZoom) return const _Nowhere();
              return Positioned(
                top: 108 + topInset,
                left: 0,
                right: 0,
                child: const Center(child: ZoomInHint()),
              );
            },
          ),
          Positioned(
            right: 16,
            top: 110 + topInset,
            child: Column(
              children: [
                MapControlButton(
                  icon: Icons.my_location,
                  onTap: _recenterOnUser,
                ),
                const SizedBox(height: 8),
                MapControlButton(icon: Icons.home, onTap: _resetToDefaultView),
                const SizedBox(height: 8),
                MapControlButton(
                  icon: Icons.search,
                  onTap: () {
                    _scaffoldKey.currentState?.openDrawer();
                    _searchFocusNode.requestFocus();
                  },
                ),
                const SizedBox(height: 8),
                MapControlButton(
                  icon: Icons.near_me,
                  onTap: () => _showComingSoon('Route planner'),
                ),
                const SizedBox(height: 8),
                MapControlButton(
                  icon: Icons.list,
                  active: state?.showLegend ?? true,
                  onTap: _viewModel.toggleLegend,
                ),
                const SizedBox(height: 8),
                MapControlButton(
                  icon: Icons.delete_outline,
                  iconColor: AppColors.danger,
                  onTap: _cancelAnalysis,
                ),
                const SizedBox(height: 8),
                MapControlButton(
                  icon: Icons.traffic,
                  active: state?.showLiveTraffic ?? false,
                  onTap: _viewModel.toggleLiveTrafficLayer,
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16 + bottomInset,
            child: (state?.showSosMenu ?? false)
                ? SosActionMenu(
                    onReportIncident: _openTriageEntry,
                    onCallForHelp: _call112,
                    onClose: _viewModel.toggleSosMenu,
                  )
                : FloatingActionButton(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.circular(200),
                    ),
                    backgroundColor: AppColors.danger,
                    onPressed: _viewModel.toggleSosMenu,
                    child: const Text('🚨', style: TextStyle(fontSize: 26)),
                  ),
          ),
          if (showFloatingAnalysisControls)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + bottomInset,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state!.showChangeModeCard) ...[
                    ChangeCommuteModeCard(
                      selectedMode: state.selectedTransportMode,
                      onModeSelected: _changeCommuteMode,
                      onClose: _viewModel.dismissChangeModeCard,
                    ),
                    const SizedBox(height: 8),
                  ],
                  ViewResultsButton(onTap: _viewModel.reopenAnalysisSheet),
                ],
              ),
            ),
          // Always resolves to a Positioned (even the "nothing to show" case)
          // rather than a bare SizedBox: a Stack with even one genuinely
          // non-positioned child sizes itself to that child instead of
          // filling the screen, which collapsed every other Positioned
          // sibling — including the SOS FAB — to (0, 0).
          ValueListenableBuilder<bool>(
            valueListenable: _pingActive,
            builder: (context, active, _) {
              if (!active) return const _Nowhere();
              return ValueListenableBuilder<Offset?>(
                valueListenable: _popupAnchor,
                builder: (context, anchor, _) => anchor == null
                    ? const _Nowhere()
                    : Positioned(
                        left: anchor.dx - 60,
                        top: anchor.dy - 60,
                        child: const IgnorePointer(
                          child: _PingRadarPulse(size: 120),
                        ),
                      ),
              );
            },
          ),
          if (state?.originSelection != null && state!.showGetHelpFast)
            Positioned.fill(
              child: ValueListenableBuilder<bool>(
                valueListenable: _pingActive,
                builder: (context, pinging, child) => Align(
                  alignment: pinging
                      ? Alignment.bottomCenter
                      : Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: pinging ? 16 + bottomInset : 0,
                    ),
                    child: child,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 340,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.85,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      child: GetHelpSheet(
                        isPinnedLocation: !state.originSelection!.followsUser,
                        onDismiss: _clearPopup,
                        onBack: _viewModel.closeGetHelpFast,
                        origin: state.originSelection!.point,
                        onPingActiveChanged: (active) =>
                            _pingActive.value = active,
                        onGoToHelp: _startGoToHelp,
                        initialPingCategory: _pendingSosCategory,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (state?.originSelection != null)
            ValueListenableBuilder<Offset?>(
              valueListenable: _popupAnchor,
              builder: (context, anchor, _) => anchor == null
                  ? const SizedBox.shrink()
                  : _AnchoredPopup(
                      anchor: anchor,
                      child: AccessOriginPopup(
                        title: state!.originSelection!.title,
                        selectedMode: state.selectedTransportMode,
                        onModeSelected: _viewModel.setSelectedMode,
                        analyzeLabel: state.originSelection!.analyzeLabel,
                        onAnalyzeAccess: () => _runAnalysis(
                          state.originSelection!.point,
                          followsUser: state.originSelection!.followsUser,
                        ),
                        onGetHelpFast: _viewModel.openGetHelpFast,
                        onClose: _clearPopup,
                      ),
                    ),
            ),
          if (state?.selectedFacility != null)
            ValueListenableBuilder<Offset?>(
              valueListenable: _popupAnchor,
              builder: (context, anchor, _) => anchor == null
                  ? const SizedBox.shrink()
                  : _AnchoredPopup(
                      anchor: anchor,
                      child: FacilityPopupCard(
                        facility: state!.selectedFacility!,
                        onViewInfo: () =>
                            _viewFacilityInfo(state.selectedFacility!),
                        onAnalyzeAccess: () => _runAnalysis(
                          GeoPoint(
                            latitude: state.selectedFacility!.latitude,
                            longitude: state.selectedFacility!.longitude,
                          ),
                        ),
                        onGetDirections: () =>
                            _getDirectionsToFacility(state.selectedFacility!),
                        onSaveFacility: _saveFacility,
                        onClose: _clearPopup,
                      ),
                    ),
            ),
          if (state?.goToHelpRoute != null &&
              state?.goToHelpDestination != null) ...[
            Positioned(
              top: 108 + topInset,
              left: 16,
              right: 16,
              child: Center(
                child: GoToHelpModeBar(
                  selectedMode: state!.selectedTransportMode,
                  onModeSelected: _changeGoToHelpMode,
                ),
              ),
            ),
            Positioned(
              // Below the mode bar rather than beside it — sharing a row
              // caused the mode bar's own width to be squeezed enough to
              // overflow (4 chips need ~310px, the shared-row space left
              // only ~280px). Also kept clear of the right-side map
              // control button column (44px wide at right:16, so right:72
              // leaves an 8px gap past its left edge).
              top: 168 + topInset,
              right: 72,
              child: RouteActiveChip(
                destinationName: state.goToHelpDestination!.name,
                route: state.goToHelpRoute!,
                onClose: _closeGoToHelp,
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + bottomInset,
              child: GoToHelpCard(
                destination: state.goToHelpDestination!,
                route: state.goToHelpRoute!,
                expanded: state.goToHelpCardExpanded,
                onToggleExpanded: _viewModel.toggleGoToHelpCard,
                onCall112: _call112,
                onStart: _startTracking,
                onSendSosInstead: _viewModel.openGoToHelpSosConfirm,
                onVoiceDirections: _viewModel.toggleGoToHelpVoice,
                onClose: _closeGoToHelp,
                tracking: state.goToHelpTracking,
                accuracyMeters: state.goToHelpAccuracyMeters,
                voiceEnabled: state.goToHelpVoiceEnabled,
                onStop: _viewModel.stopGoToHelpTracking,
                onViewSteps: () =>
                    _viewGoToHelpSteps(state.goToHelpRoute!.steps),
                sosConfirming: state.goToHelpSosConfirming,
                onCancelSosConfirm: _viewModel.closeGoToHelpSosConfirm,
                onConfirmSos: _confirmSosInstead,
              ),
            ),
          ],
          if (state?.goToHelpLoading ?? false)
            const Positioned.fill(child: CalculatingRouteOverlay()),
          if (state?.showAnalysisSheet == true && state?.activeAnalysis != null)
            Positioned.fill(
              child: AccessAnalysisSheet(
                result: state!.activeAnalysis!,
                onMapRoute: (destination) async {
                  final origin = await _viewModel.resolveRouteOrigin();
                  if (origin != null) await _mapRouteTo(origin, destination);
                },
                onDirections: (destination) async {
                  final origin = await _viewModel.resolveRouteOrigin();
                  if (origin != null) {
                    await _getDirectionsTo(origin, destination);
                  }
                },
                onClose: _viewModel.dismissAnalysisSheet,
              ),
            ),
        ],
      ),
    );
  }
}

/// Positions [child] so its bottom edge sits just above [anchor] (a point in
/// the map's local coordinate space), horizontally centered on it.
///
/// Deliberately unclamped: [anchor] is continuously re-projected from a real
/// geo-point as the camera moves (see `_syncPopupAnchor`), so the popup must
/// be free to move off-screen exactly like a real map annotation would when
/// panned away — clamping it to stay visible was the bug that made it look
/// like the popup was "following" the user instead of the map. The
/// surrounding `Stack` clips it once it's outside the visible area, same as
/// a marker naturally would be.
class _AnchoredPopup extends StatelessWidget {
  const _AnchoredPopup({required this.anchor, required this.child});

  final Offset anchor;
  final Widget child;

  static const _popupWidth = 260.0;

  @override
  Widget build(BuildContext context) {
    final left = anchor.dx - _popupWidth / 2;
    return Positioned(
      left: left,
      top: anchor.dy,
      child: FractionalTranslation(
        translation: const Offset(0, -1),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: _popupWidth, child: child),
              const _PopupTail(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small triangular pointer beneath an anchored popup — echoes the
/// callout-bubble tail the web platform's dropped-pin/facility popups use
/// to visually connect the card to its exact point on the map.
class _PopupTail extends StatelessWidget {
  const _PopupTail();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(20, 10), painter: _PopupTailPainter());
  }
}

class _PopupTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.backgroundSurface);
  }

  @override
  bool shouldRepaint(covariant _PopupTailPainter oldDelegate) => false;
}

/// A zero-size but still-`Positioned` placeholder — see the comment at its
/// call site for why this can't just be a bare `SizedBox.shrink()`.
class _Nowhere extends StatelessWidget {
  const _Nowhere();

  @override
  Widget build(BuildContext context) => const Positioned(
    left: 0,
    top: 0,
    width: 0,
    height: 0,
    child: SizedBox.shrink(),
  );
}

class _PingRadarPulse extends StatefulWidget {
  const _PingRadarPulse({required this.size});

  final double size;

  @override
  State<_PingRadarPulse> createState() => _PingRadarPulseState();
}

class _PingRadarPulseState extends State<_PingRadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t).clamp(0, 1),
                child: Container(
                  width: widget.size * t,
                  height: widget.size * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.danger.withValues(alpha: 0.15),
                  ),
                ),
              ),
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
