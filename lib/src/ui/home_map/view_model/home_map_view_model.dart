import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/result.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/geo_point.dart';
import '../../../data/repositories/access_analysis_repository.dart';
import '../../../data/repositories/facility_repository.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../data/services/access_analysis_service.dart';
import '../../../data/services/voice_directions_service.dart';

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
    this.showEmergencyFacilities = true,
    this.showLiveTraffic = false,
    this.analysisThresholdMinutes = kAccessAnalysisThresholdMinutes,
    this.originSelection,
    this.selectedFacility,
    this.showGetHelpFast = false,
    this.goToHelpDestination,
    this.goToHelpRoute,
    this.goToHelpCardExpanded = true,
    this.goToHelpLoading = false,
    this.goToHelpOrigin,
    this.goToHelpFollowsUser = false,
    this.goToHelpTracking = false,
    this.goToHelpAccuracyMeters,
    this.goToHelpVoiceEnabled = false,
    this.goToHelpSosConfirming = false,
    this.errorMessage,
  });

  final List<Facility> facilities;
  final GeoPoint center;
  final LocationAccessStatus locationStatus;

  final FacilityCategory? selectedFilter;
  final TransportMode selectedTransportMode;

  /// Master visibility for facility markers — the drawer's "Emergency
  /// Facilities" layer toggle, independent of [selectedFilter].
  final bool showEmergencyFacilities;

  /// The drawer's/side-button's "Live Traffic" map layer toggle.
  final bool showLiveTraffic;

  /// The Accessibility Analyzer's Max Time Threshold, set from the drawer.
  final int analysisThresholdMinutes;

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

  /// Whether the origin popup is showing its "Get Help Fast" content in
  /// place of the normal analyzer content — swaps in-place, anchored at the
  /// same map point, rather than opening a separate sheet.
  final bool showGetHelpFast;

  /// The nearest facility of the chosen category, and the active route to
  /// it — non-null together for the whole "Go to Help" lifetime, matching
  /// the web platform's turn-by-turn card.
  final Facility? goToHelpDestination;
  final DirectionsRoute? goToHelpRoute;

  /// Whether the Go to Help card shows its full turn-by-turn body or just
  /// the collapsed time/destination summary.
  final bool goToHelpCardExpanded;

  /// Whether a route is being (re)fetched — either the first time a category
  /// is tapped, or after a mode-bar change — matches the web platform's
  /// "Calculating Route… / Fetching live road data" overlay.
  final bool goToHelpLoading;

  /// The origin Go to Help started from, and whether it should track a
  /// fresh GPS fix rather than stay anchored to that point — captured from
  /// [OriginSelection] when the route starts, since [originSelection]
  /// itself gets cleared once Go to Help's card takes over the popup.
  final GeoPoint? goToHelpOrigin;
  final bool goToHelpFollowsUser;

  /// Whether "Start" has been tapped — the live-navigation card layout
  /// (FOLLOWING YOU header, GPS signal) instead of the static preview, and
  /// [goToHelpOrigin]/[goToHelpRoute] now track the live GPS stream rather
  /// than a one-shot fetch.
  final bool goToHelpTracking;

  /// The last GPS fix's accuracy while tracking, for the "Weak/Good GPS
  /// signal" line — null when not tracking or before the first fix arrives.
  final double? goToHelpAccuracyMeters;

  /// Whether spoken turn-by-turn instructions are on — matches the web
  /// platform's "Voice directions" toggle.
  final bool goToHelpVoiceEnabled;

  /// Whether the "Who do you need?" confirmation is showing, after tapping
  /// "Send SOS instead" — matches the web platform, which confirms before
  /// clearing the route and handing off into a ping.
  final bool goToHelpSosConfirming;

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
    bool? showEmergencyFacilities,
    bool? showLiveTraffic,
    int? analysisThresholdMinutes,
    Object? originSelection = _unset,
    Object? selectedFacility = _unset,
    bool? showGetHelpFast,
    Object? goToHelpDestination = _unset,
    Object? goToHelpRoute = _unset,
    bool? goToHelpCardExpanded,
    bool? goToHelpLoading,
    Object? goToHelpOrigin = _unset,
    bool? goToHelpFollowsUser,
    bool? goToHelpTracking,
    Object? goToHelpAccuracyMeters = _unset,
    bool? goToHelpVoiceEnabled,
    bool? goToHelpSosConfirming,
    Object? errorMessage = _unset,
  }) {
    return HomeMapState(
      facilities: facilities ?? this.facilities,
      center: center ?? this.center,
      locationStatus: locationStatus ?? this.locationStatus,
      selectedFilter: identical(selectedFilter, _unset)
          ? this.selectedFilter
          : selectedFilter as FacilityCategory?,
      selectedTransportMode:
          selectedTransportMode ?? this.selectedTransportMode,
      activeAnalysis: identical(activeAnalysis, _unset)
          ? this.activeAnalysis
          : activeAnalysis as AccessAnalysisResult?,
      activeAnalysisOrigin: identical(activeAnalysisOrigin, _unset)
          ? this.activeAnalysisOrigin
          : activeAnalysisOrigin as GeoPoint?,
      activeAnalysisFollowsUser:
          activeAnalysisFollowsUser ?? this.activeAnalysisFollowsUser,
      showAnalysisSheet: showAnalysisSheet ?? this.showAnalysisSheet,
      showChangeModeCard: showChangeModeCard ?? this.showChangeModeCard,
      showLegend: showLegend ?? this.showLegend,
      showSosMenu: showSosMenu ?? this.showSosMenu,
      showEmergencyFacilities:
          showEmergencyFacilities ?? this.showEmergencyFacilities,
      showLiveTraffic: showLiveTraffic ?? this.showLiveTraffic,
      analysisThresholdMinutes:
          analysisThresholdMinutes ?? this.analysisThresholdMinutes,
      originSelection: identical(originSelection, _unset)
          ? this.originSelection
          : originSelection as OriginSelection?,
      selectedFacility: identical(selectedFacility, _unset)
          ? this.selectedFacility
          : selectedFacility as Facility?,
      showGetHelpFast: showGetHelpFast ?? this.showGetHelpFast,
      goToHelpDestination: identical(goToHelpDestination, _unset)
          ? this.goToHelpDestination
          : goToHelpDestination as Facility?,
      goToHelpRoute: identical(goToHelpRoute, _unset)
          ? this.goToHelpRoute
          : goToHelpRoute as DirectionsRoute?,
      goToHelpCardExpanded: goToHelpCardExpanded ?? this.goToHelpCardExpanded,
      goToHelpLoading: goToHelpLoading ?? this.goToHelpLoading,
      goToHelpOrigin: identical(goToHelpOrigin, _unset)
          ? this.goToHelpOrigin
          : goToHelpOrigin as GeoPoint?,
      goToHelpFollowsUser: goToHelpFollowsUser ?? this.goToHelpFollowsUser,
      goToHelpTracking: goToHelpTracking ?? this.goToHelpTracking,
      goToHelpAccuracyMeters: identical(goToHelpAccuracyMeters, _unset)
          ? this.goToHelpAccuracyMeters
          : goToHelpAccuracyMeters as double?,
      goToHelpVoiceEnabled: goToHelpVoiceEnabled ?? this.goToHelpVoiceEnabled,
      goToHelpSosConfirming:
          goToHelpSosConfirming ?? this.goToHelpSosConfirming,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
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
  StreamSubscription<TrackedPosition>? _trackingSubscription;
  DateTime? _lastGoToHelpRouteFetch;
  String? _lastSpokenInstruction;

  @override
  Future<HomeMapState> build() {
    ref.onDispose(() => _trackingSubscription?.cancel());
    return _load();
  }

  Future<HomeMapState> _load() async {
    final locationResult = await ref
        .read(locationRepositoryProvider)
        .currentPosition();
    final center = locationResult.position ?? defaultMapCenter;

    final facilitiesResult = await ref
        .read(facilityRepositoryProvider)
        .allFacilities();
    final facilities = switch (facilitiesResult) {
      Ok(:final value) => value,
      Err() => const <Facility>[],
    };

    final locationMessage =
        locationResult.status == LocationAccessStatus.granted
        ? null
        : locationStatusMessage(locationResult.status);
    final facilitiesMessage = switch (facilitiesResult) {
      Ok() => null,
      Err(:final failure) => failure.userMessage,
    };

    return HomeMapState(
      facilities: facilities,
      center: center,
      locationStatus: locationResult.status,
      // Location's own message takes priority when both fail — it's the
      // more fundamentally blocking of the two (no facilities is a broken
      // list; no location is a broken map).
      errorMessage: locationMessage ?? facilitiesMessage,
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

  void _setError(String message) =>
      _update((s) => s.copyWith(errorMessage: message));

  void clearErrorMessage() => _update((s) => s.copyWith(errorMessage: null));

  void selectFilter(FacilityCategory? filter) =>
      _update((s) => s.copyWith(selectedFilter: filter));

  /// Just switches the selected transport mode — used by the origin popup's
  /// mode picker before an analysis has been run. See [changeCommuteMode]
  /// for switching mode while an analysis is already active.
  void setSelectedMode(TransportMode mode) =>
      _update((s) => s.copyWith(selectedTransportMode: mode));

  /// Stops the live position stream backing "Start" tracking, if any —
  /// called whenever the Go to Help route itself is being torn down, so a
  /// stale subscription doesn't keep updating a route that's no longer
  /// shown.
  void _cancelTracking() {
    _trackingSubscription?.cancel();
    _trackingSubscription = null;
    _lastSpokenInstruction = null;
    unawaited(ref.read(voiceDirectionsServiceProvider).stop());
  }

  void selectOrigin({
    required GeoPoint point,
    required String title,
    required String analyzeLabel,
    bool followsUser = false,
  }) {
    _cancelTracking();
    _update(
      (s) => s.copyWith(
        originSelection: OriginSelection(
          point: point,
          title: title,
          analyzeLabel: analyzeLabel,
          followsUser: followsUser,
        ),
        selectedFacility: null,
        showGetHelpFast: false,
        goToHelpDestination: null,
        goToHelpRoute: null,
        goToHelpOrigin: null,
        goToHelpFollowsUser: false,
        goToHelpTracking: false,
        goToHelpAccuracyMeters: null,
        goToHelpSosConfirming: false,
      ),
    );
  }

  void selectFacility(Facility facility) {
    _cancelTracking();
    _update(
      (s) => s.copyWith(
        selectedFacility: facility,
        originSelection: null,
        showGetHelpFast: false,
        goToHelpDestination: null,
        goToHelpRoute: null,
        goToHelpOrigin: null,
        goToHelpFollowsUser: false,
        goToHelpTracking: false,
        goToHelpAccuracyMeters: null,
        goToHelpSosConfirming: false,
      ),
    );
  }

  void clearPopups() {
    _cancelTracking();
    _update(
      (s) => s.copyWith(
        originSelection: null,
        selectedFacility: null,
        showGetHelpFast: false,
        goToHelpDestination: null,
        goToHelpRoute: null,
        goToHelpOrigin: null,
        goToHelpFollowsUser: false,
        goToHelpTracking: false,
        goToHelpAccuracyMeters: null,
        goToHelpSosConfirming: false,
      ),
    );
  }

  /// Opens the "Who do you need?" confirmation shown by "Send SOS instead" —
  /// matches the web platform, which confirms before clearing the route.
  void openGoToHelpSosConfirm() =>
      _update((s) => s.copyWith(goToHelpSosConfirming: true));

  void closeGoToHelpSosConfirm() =>
      _update((s) => s.copyWith(goToHelpSosConfirming: false));

  /// Swaps the origin popup's content to "Get Help Fast," anchored at the
  /// same map point — matches the web platform, where this replaces the
  /// analyzer card in place rather than opening a separate sheet.
  void openGetHelpFast() => _update((s) => s.copyWith(showGetHelpFast: true));

  /// Swaps back to the origin popup (dropped pin or "Your Location") that
  /// "Get Help Fast" was opened from, without closing the popup entirely.
  void closeGetHelpFast() => _update((s) => s.copyWith(showGetHelpFast: false));

  void toggleLegend() => _update((s) => s.copyWith(showLegend: !s.showLegend));

  void toggleSosMenu() =>
      _update((s) => s.copyWith(showSosMenu: !s.showSosMenu));

  void closeSosMenu() => _update((s) => s.copyWith(showSosMenu: false));

  void dismissChangeModeCard() =>
      _update((s) => s.copyWith(showChangeModeCard: false));

  void toggleEmergencyFacilitiesLayer() => _update(
    (s) => s.copyWith(showEmergencyFacilities: !s.showEmergencyFacilities),
  );

  void toggleLiveTrafficLayer() =>
      _update((s) => s.copyWith(showLiveTraffic: !s.showLiveTraffic));

  void setAnalysisThreshold(int minutes) =>
      _update((s) => s.copyWith(analysisThresholdMinutes: minutes));

  void dismissAnalysisSheet() =>
      _update((s) => s.copyWith(showAnalysisSheet: false));

  void reopenAnalysisSheet() =>
      _update((s) => s.copyWith(showAnalysisSheet: true));

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
    switch (await ref
        .read(accessAnalysisRepositoryProvider)
        .analyze(
          origin: origin,
          mode: state.value?.selectedTransportMode ?? TransportMode.driving,
          thresholdMinutes:
              state.value?.analysisThresholdMinutes ??
              kAccessAnalysisThresholdMinutes,
        )) {
      case Ok(:final value):
        result = value;
      case Err(:final failure):
        _setError(failure.userMessage);
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
      await runAnalysis(
        origin,
        openSheet: false,
        followsUser: current!.activeAnalysisFollowsUser,
      );
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
      selectOrigin(
        point: point,
        title: 'Your Location',
        analyzeLabel: 'Analyze Access',
        followsUser: true,
      );
    }
    return point;
  }

  Future<DirectionsRoute?> fetchRoute(
    GeoPoint origin,
    GeoPoint destination,
  ) async {
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

  /// Finds the nearest [category] facility to the current origin selection
  /// and routes to it — matches the web platform's "Go to Help," which
  /// auto-picks the closest facility of the chosen type rather than asking
  /// the user to pick one.
  ///
  /// For "Your Location," this re-fetches a fresh GPS position instead of
  /// reusing the point captured when the origin was selected: the native
  /// map puck is driven live by CoreLocation and keeps refining/drifting
  /// after that snapshot was taken, so a stale point can sit meters away
  /// from where the puck is actually drawn — reading as the route line
  /// overshooting the icon.
  Future<void> startGoToHelp(FacilityCategory category) async {
    final originSelection = state.value?.originSelection;
    if (originSelection == null) return;
    var origin = originSelection.point;
    if (originSelection.followsUser) {
      final result = await ref
          .read(locationRepositoryProvider)
          .currentPosition();
      origin = result.position ?? origin;
    }

    final facilities = state.value?.facilities ?? const <Facility>[];
    Facility? nearest;
    var nearestDistance = double.infinity;
    for (final facility in facilities) {
      if (facility.category != category) continue;
      final distance = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        facility.latitude,
        facility.longitude,
      );
      if (distance < nearestDistance) {
        nearest = facility;
        nearestDistance = distance;
      }
    }
    if (nearest == null) {
      _setError('No nearby ${category.displayLabel} found');
      return;
    }

    _update((s) => s.copyWith(goToHelpLoading: true));
    final route = await fetchRoute(
      origin,
      GeoPoint(latitude: nearest.latitude, longitude: nearest.longitude),
    );
    if (route == null) {
      _update((s) => s.copyWith(goToHelpLoading: false));
      return;
    }

    _update(
      (s) => s.copyWith(
        goToHelpDestination: nearest,
        goToHelpRoute: route,
        goToHelpCardExpanded: true,
        goToHelpLoading: false,
        goToHelpOrigin: origin,
        goToHelpFollowsUser: originSelection.followsUser,
        showGetHelpFast: false,
        originSelection: null,
        selectedFacility: null,
      ),
    );
  }

  /// Re-fetches the active Go to Help route with the current
  /// [HomeMapState.selectedTransportMode] — used when the mode bar changes.
  /// Also re-resolves the origin when it's tracking live location (see
  /// [startGoToHelp]), so the drawn line keeps matching the map's puck
  /// instead of anchoring to wherever the user was when the route started.
  Future<void> refreshGoToHelpRoute() async {
    final current = state.value;
    final destination = current?.goToHelpDestination;
    final anchorOrigin = current?.goToHelpOrigin;
    if (current == null || destination == null || anchorOrigin == null) return;

    var origin = anchorOrigin;
    if (current.goToHelpFollowsUser) {
      final result = await ref
          .read(locationRepositoryProvider)
          .currentPosition();
      origin = result.position ?? origin;
    }

    _update((s) => s.copyWith(goToHelpLoading: true));
    final route = await fetchRoute(
      origin,
      GeoPoint(
        latitude: destination.latitude,
        longitude: destination.longitude,
      ),
    );
    _update(
      (s) => s.copyWith(
        goToHelpRoute: route ?? s.goToHelpRoute,
        goToHelpOrigin: origin,
        goToHelpLoading: false,
      ),
    );
  }

  void toggleGoToHelpCard() =>
      _update((s) => s.copyWith(goToHelpCardExpanded: !s.goToHelpCardExpanded));

  /// Cancels the active Go to Help route entirely — matches the web
  /// platform's "Route active" chip close button.
  void closeGoToHelp() {
    _cancelTracking();
    _update(
      (s) => s.copyWith(
        goToHelpDestination: null,
        goToHelpRoute: null,
        goToHelpLoading: false,
        goToHelpOrigin: null,
        goToHelpFollowsUser: false,
        goToHelpTracking: false,
        goToHelpAccuracyMeters: null,
        goToHelpSosConfirming: false,
      ),
    );
  }

  /// Starts live GPS tracking for the active route — the web platform's
  /// "Start": the origin now follows the live position stream instead of a
  /// one-shot fetch, and the route is periodically re-fetched from wherever
  /// the user actually is.
  Future<void> startGoToHelpTracking() async {
    final current = state.value;
    if (current?.goToHelpDestination == null) return;
    _cancelTracking();
    _lastGoToHelpRouteFetch = null;
    _update((s) => s.copyWith(goToHelpTracking: true));
    _trackingSubscription = ref
        .read(locationRepositoryProvider)
        .positionStream()
        .listen(_onTrackedPosition);

    final route = current?.goToHelpRoute;
    if (route != null && (current?.goToHelpVoiceEnabled ?? false)) {
      _speakUpcomingInstruction(route, force: true);
    }
  }

  /// Stops live tracking and reverts to the static route preview — the web
  /// platform's "Stop." Leaves the route itself (destination, last-known
  /// path) in place, unlike [closeGoToHelp].
  void stopGoToHelpTracking() {
    _cancelTracking();
    _update((s) => s.copyWith(goToHelpTracking: false));
  }

  /// Moves the route's origin to each live GPS fix and, at most once every
  /// 10 seconds, re-fetches the route from there — re-fetching on every fix
  /// (which can arrive every few meters of movement) would hammer the
  /// Directions API far more than the ETA/geometry actually needs.
  Future<void> _onTrackedPosition(TrackedPosition tracked) async {
    final destination = state.value?.goToHelpDestination;
    if (destination == null) {
      stopGoToHelpTracking();
      return;
    }

    _update(
      (s) => s.copyWith(
        goToHelpOrigin: tracked.point,
        goToHelpAccuracyMeters: tracked.accuracyMeters,
      ),
    );

    final now = DateTime.now();
    final last = _lastGoToHelpRouteFetch;
    if (last != null && now.difference(last) < const Duration(seconds: 10)) {
      return;
    }
    _lastGoToHelpRouteFetch = now;

    final route = await fetchRoute(
      tracked.point,
      GeoPoint(
        latitude: destination.latitude,
        longitude: destination.longitude,
      ),
    );
    if (route != null) {
      _update((s) => s.copyWith(goToHelpRoute: route));
      if (state.value?.goToHelpVoiceEnabled ?? false) {
        _speakUpcomingInstruction(route);
      }
    }
  }

  /// Turns spoken turn-by-turn instructions on/off — the web platform's
  /// "Voice directions" toggle. Enabling it mid-route immediately announces
  /// the current next instruction, the same feedback a driver gets from
  /// turning voice on partway through a real navigation app.
  void toggleGoToHelpVoice() {
    final enabling = !(state.value?.goToHelpVoiceEnabled ?? false);
    _update((s) => s.copyWith(goToHelpVoiceEnabled: enabling));
    if (!enabling) {
      _lastSpokenInstruction = null;
      unawaited(ref.read(voiceDirectionsServiceProvider).stop());
      return;
    }
    final route = state.value?.goToHelpRoute;
    if (route != null) _speakUpcomingInstruction(route, force: true);
  }

  /// Speaks [route]'s next instruction — but only when it's actually new,
  /// since [_onTrackedPosition] calls this on every route refetch (every
  /// ~10s while tracking) and re-announcing an unchanged instruction on
  /// every refetch would be constant, useless chatter. [force] bypasses
  /// that for the "just turned voice on" case, where re-stating the current
  /// instruction is the whole point even if it hasn't changed.
  void _speakUpcomingInstruction(DirectionsRoute route, {bool force = false}) {
    if (route.steps.isEmpty) return;
    final instruction = route.steps.first.instruction;
    if (instruction.isEmpty) return;
    if (!force && instruction == _lastSpokenInstruction) return;
    _lastSpokenInstruction = instruction;
    unawaited(ref.read(voiceDirectionsServiceProvider).speak(instruction));
  }
}

final homeMapViewModelProvider =
    AsyncNotifierProvider<HomeMapViewModel, HomeMapState>(HomeMapViewModel.new);
