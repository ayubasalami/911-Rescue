import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/geo_point.dart';
import '../../../data/repositories/access_analysis_repository.dart';
import '../../../data/repositories/facility_repository.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../data/services/access_analysis_service.dart';

const defaultMapCenter = GeoPoint(latitude: 6.5244, longitude: 3.3792);

String locationStatusMessage(LocationAccessStatus status) => switch (status) {
  LocationAccessStatus.granted => '',
  LocationAccessStatus.denied =>
    'Location access denied — showing Lagos by default.',
  LocationAccessStatus.deniedForever =>
    'Location permanently denied — enable it in Settings to see nearby facilities.',
  LocationAccessStatus.serviceDisabled =>
    'Turn on location services to see nearby facilities.',
  LocationAccessStatus.timedOut =>
    'Couldn\'t get your location in time — showing Lagos by default.',
};

/// The popup content for "Your Location" or a dropped pin. Distinct from a
/// [Facility] selection, which has its own identity and category.
class OriginSelection {
  const OriginSelection({
    required this.point,
    required this.title,
    required this.analyzeLabel,
    this.followsUser = false,
  });

  final GeoPoint point;
  final String title;
  final String analyzeLabel;

  /// Whether [point] is the user's live location, rather than a dropped
  /// pin — determines whether routes from here should track a fresh GPS
  /// fix or stay anchored to the point that was analyzed.
  final bool followsUser;
}

/// Sentinel for [HomeMapState.copyWith] so nullable fields can be
/// explicitly cleared, distinct from "leave unchanged".
const _unset = Object();

class HomeMapState {
  const HomeMapState({
    required this.facilities,
    required this.center,
    required this.locationStatus,
    this.selectedFilter,
    this.selectedTransportMode = TransportMode.driving,
    this.activeAnalysis,
    this.activeAnalysisOrigin,
    this.activeAnalysisFollowsUser = false,
    this.showAnalysisSheet = false,
    this.showChangeModeCard = true,
    this.showLegend = true,
    this.showSosMenu = false,
    this.originSelection,
    this.selectedFacility,
    this.errorMessage,
  });

  final List<Facility> facilities;
  final GeoPoint center;
  final LocationAccessStatus locationStatus;

  final FacilityCategory? selectedFilter;
  final TransportMode selectedTransportMode;

  final AccessAnalysisResult? activeAnalysis;
  final GeoPoint? activeAnalysisOrigin;
  final bool activeAnalysisFollowsUser;
  final bool showAnalysisSheet;
  final bool showChangeModeCard;

  final bool showLegend;
  final bool showSosMenu;

  /// At most one of these is non-null at a time — selecting one clears
  /// the other.
  final OriginSelection? originSelection;
  final Facility? selectedFacility;

  /// A one-shot message for the View to surface (e.g. via SnackBar), then
  /// clear with [HomeMapViewModel.clearErrorMessage] so it isn't shown
  /// again on the next rebuild.
  final String? errorMessage;

  HomeMapState copyWith({
    List<Facility>? facilities,
    GeoPoint? center,
    LocationAccessStatus? locationStatus,
    Object? selectedFilter = _unset,
    TransportMode? selectedTransportMode,
    Object? activeAnalysis = _unset,
    Object? activeAnalysisOrigin = _unset,
    bool? activeAnalysisFollowsUser,
    bool? showAnalysisSheet,
    bool? showChangeModeCard,
    bool? showLegend,
    bool? showSosMenu,
    Object? originSelection = _unset,
    Object? selectedFacility = _unset,
    Object? errorMessage = _unset,
  }) {
    return HomeMapState(
      facilities: facilities ?? this.facilities,
      center: center ?? this.center,
      locationStatus: locationStatus ?? this.locationStatus,
      selectedFilter: identical(selectedFilter, _unset)
          ? this.selectedFilter
          : selectedFilter as FacilityCategory?,
      selectedTransportMode: selectedTransportMode ?? this.selectedTransportMode,
      activeAnalysis: identical(activeAnalysis, _unset)
          ? this.activeAnalysis
          : activeAnalysis as AccessAnalysisResult?,
      activeAnalysisOrigin: identical(activeAnalysisOrigin, _unset)
          ? this.activeAnalysisOrigin
          : activeAnalysisOrigin as GeoPoint?,
      activeAnalysisFollowsUser: activeAnalysisFollowsUser ?? this.activeAnalysisFollowsUser,
      showAnalysisSheet: showAnalysisSheet ?? this.showAnalysisSheet,
      showChangeModeCard: showChangeModeCard ?? this.showChangeModeCard,
      showLegend: showLegend ?? this.showLegend,
      showSosMenu: showSosMenu ?? this.showSosMenu,
      originSelection: identical(originSelection, _unset)
          ? this.originSelection
          : originSelection as OriginSelection?,
      selectedFacility: identical(selectedFacility, _unset)
          ? this.selectedFacility
          : selectedFacility as Facility?,
      errorMessage: identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
    );
  }
}

/// Owns all of Home/Map's business state and orchestration: which facility
/// filter/transport mode is selected, the active Accessibility Analyzer
/// result and its lifecycle, and what's currently selected for a popup.
///
/// Deliberately does not know about `BuildContext`, `Navigator`, or the
/// Mapbox SDK's platform view/annotation objects — those stay in
/// [HomeMapScreen] and [MapAnnotationController], since a ViewModel holding
/// either would defeat the point of separating them out.
class HomeMapViewModel extends AsyncNotifier<HomeMapState> {
  @override
  Future<HomeMapState> build() => _load();

  Future<HomeMapState> _load() async {
    final locationResult = await ref.read(locationRepositoryProvider).currentPosition();
    final center = locationResult.position ?? defaultMapCenter;
    final facilities = await ref
        .read(facilityRepositoryProvider)
        .nearbyFacilities(latitude: center.latitude, longitude: center.longitude);
    return HomeMapState(
      facilities: facilities,
      center: center,
      locationStatus: locationResult.status,
      errorMessage: locationResult.status == LocationAccessStatus.granted
          ? null
          : locationStatusMessage(locationResult.status),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  void _update(HomeMapState Function(HomeMapState current) update) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(update(current));
  }

  void _setError(String message) => _update((s) => s.copyWith(errorMessage: message));

  void clearErrorMessage() => _update((s) => s.copyWith(errorMessage: null));

  void selectFilter(FacilityCategory? filter) => _update((s) => s.copyWith(selectedFilter: filter));

  /// Just switches the selected transport mode — used by the origin popup's
  /// mode picker before an analysis has been run. See [changeCommuteMode]
  /// for switching mode while an analysis is already active.
  void setSelectedMode(TransportMode mode) =>
      _update((s) => s.copyWith(selectedTransportMode: mode));

  void selectOrigin({
    required GeoPoint point,
    required String title,
    required String analyzeLabel,
    bool followsUser = false,
  }) => _update(
    (s) => s.copyWith(
      originSelection: OriginSelection(
        point: point,
        title: title,
        analyzeLabel: analyzeLabel,
        followsUser: followsUser,
      ),
      selectedFacility: null,
    ),
  );

  void selectFacility(Facility facility) =>
      _update((s) => s.copyWith(selectedFacility: facility, originSelection: null));

  void clearPopups() => _update((s) => s.copyWith(originSelection: null, selectedFacility: null));

  void toggleLegend() => _update((s) => s.copyWith(showLegend: !s.showLegend));

  void toggleSosMenu() => _update((s) => s.copyWith(showSosMenu: !s.showSosMenu));

  void closeSosMenu() => _update((s) => s.copyWith(showSosMenu: false));

  void dismissChangeModeCard() => _update((s) => s.copyWith(showChangeModeCard: false));

  void dismissAnalysisSheet() => _update((s) => s.copyWith(showAnalysisSheet: false));

  void reopenAnalysisSheet() => _update((s) => s.copyWith(showAnalysisSheet: true));

  /// Runs (or re-runs, on a mode change) the analysis for [origin]. Leaving
  /// an analysis active and only closing its sheet must not cancel it —
  /// only [cancelAnalysis] does that.
  Future<void> runAnalysis(
    GeoPoint origin, {
    bool openSheet = true,
    bool followsUser = false,
  }) async {
    clearPopups();

    final AccessAnalysisResult result;
    try {
      result = await ref
          .read(accessAnalysisRepositoryProvider)
          .analyze(origin: origin, mode: state.value?.selectedTransportMode ?? TransportMode.driving);
    } catch (error) {
      _setError('Could not run accessibility analysis: $error');
      return;
    }

    _update(
      (s) => s.copyWith(
        activeAnalysis: result,
        activeAnalysisOrigin: origin,
        activeAnalysisFollowsUser: followsUser,
        showChangeModeCard: true,
        showAnalysisSheet: openSheet ? true : s.showAnalysisSheet,
      ),
    );
  }

  Future<void> changeCommuteMode(TransportMode mode) async {
    setSelectedMode(mode);
    final current = state.value;
    final origin = current?.activeAnalysisOrigin;
    if (origin != null) {
      await runAnalysis(origin, openSheet: false, followsUser: current!.activeAnalysisFollowsUser);
    }
  }

  Future<void> cancelAnalysis() async {
    _update(
      (s) => s.copyWith(
        activeAnalysis: null,
        activeAnalysisOrigin: null,
        activeAnalysisFollowsUser: false,
        showAnalysisSheet: false,
      ),
    );
  }

  /// The point routes/directions should start from while an analysis is
  /// active. For an analysis that followed "Your Location," this re-fetches
  /// a fresh GPS position instead of reusing the point captured when
  /// Analyze Access was tapped — that captured point goes stale relative to
  /// the live location puck the longer the analysis stays open.
  Future<GeoPoint?> resolveRouteOrigin() async {
    final current = state.value;
    if (current == null) return null;
    if (!current.activeAnalysisFollowsUser) return current.activeAnalysisOrigin;
    final result = await ref.read(locationRepositoryProvider).currentPosition();
    return result.position ?? current.activeAnalysisOrigin;
  }

  /// The user's current GPS position, surfacing a friendly message via
  /// [HomeMapState.errorMessage] on failure.
  Future<GeoPoint?> currentUserLocation() async {
    final result = await ref.read(locationRepositoryProvider).currentPosition();
    if (result.position == null) {
      _setError(locationStatusMessage(result.status));
    }
    return result.position;
  }

  Future<GeoPoint?> recenterOnUser() async {
    final point = await currentUserLocation();
    if (point != null) {
      selectOrigin(point: point, title: 'Your Location', analyzeLabel: 'Analyze Access', followsUser: true);
    }
    return point;
  }

  Future<DirectionsRoute?> fetchRoute(GeoPoint origin, GeoPoint destination) async {
    try {
      return await ref
          .read(accessAnalysisServiceProvider)
          .fetchRoute(
            origin: origin,
            destination: destination,
            mode: state.value?.selectedTransportMode ?? TransportMode.driving,
          );
    } catch (error) {
      _setError('Could not load route: $error');
      return null;
    }
  }
}

final homeMapViewModelProvider =
    AsyncNotifierProvider<HomeMapViewModel, HomeMapState>(HomeMapViewModel.new);
