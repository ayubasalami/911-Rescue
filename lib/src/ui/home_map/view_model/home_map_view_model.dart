import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' show max, min;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/analytics_events.dart';
import '../../../core/app_failure.dart';
import '../../../core/result.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/geo_point.dart';
import '../../../data/models/route_point.dart';
import '../../../data/models/triage.dart';
import '../../../core/env.dart';
import '../../../data/repositories/access_analysis_repository.dart';
import '../../../data/repositories/active_ping_repository.dart';
import '../../../data/repositories/facility_repository.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../data/services/access_analysis_service.dart';
import '../../../data/services/analytics_service.dart';
import '../../../data/services/interaction_service.dart';
import '../../../data/services/ping_service.dart';
import '../../../data/services/voice_directions_service.dart';
import '../../../utils/route_progress.dart';
import '../../../utils/turn_announcer.dart';
import '../../../utils/triage_facility_picker.dart';
import '../../core/view_model/auth_view_model.dart';

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
    this.analysisLoading = false,
    this.analysisRoute,
    this.analysisRouteName,
    this.analysisRouteChipDismissed = false,
    this.showAnalysisSheet = false,
    this.showChangeModeCard = true,
    this.showLegend = true,
    this.showSosMenu = false,
    this.showEmergencyFacilities = true,
    this.showLiveTraffic = false,
    this.showLagosBoundary = true,
    this.lagosBoundary,
    this.analysisThresholdMinutes = kAccessAnalysisThresholdMinutes,
    this.originSelection,
    this.selectedFacility,
    this.showGetHelpFast = false,
    this.showRoutePlanner = false,
    this.goToHelpDestination,
    this.goToHelpRoute,
    this.goToHelpCardExpanded = true,
    this.goToHelpLoading = false,
    this.goToHelpOrigin,
    this.goToHelpFollowsUser = false,
    this.goToHelpTracking = false,
    this.goToHelpAccuracyMeters,
    this.goToHelpArrivedTripMinutes,
    this.goToHelpProgress,
    this.goToHelpOffRoute = false,
    this.goToHelpOffRouteNotice,
    this.goToHelpRecalculating = false,
    this.goToHelpHeading,
    this.goToHelpFollowHeading = false,
    this.goToHelpVoiceEnabled = false,
    this.goToHelpSosConfirming = false,
    this.goToHelpCloseConfirming = false,
    this.routeChipDismissed = false,
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

  /// The drawer's "Lagos Boundary" map layer toggle — defaults on, matching
  /// the web platform.
  final bool showLagosBoundary;

  /// The outer ring of the Lagos state boundary polygon, fetched once at
  /// load (it's static data, ~14 KB — unlike facilities there's no reason
  /// to gate this behind zoom or cache-refresh logic). Null until that
  /// fetch completes or if it failed; [showLagosBoundary] being on with
  /// this still null just means nothing renders yet.
  final List<GeoPoint>? lagosBoundary;

  /// The Accessibility Analyzer's Max Time Threshold, set from the drawer.
  final int analysisThresholdMinutes;

  final AccessAnalysisResult? activeAnalysis;
  final GeoPoint? activeAnalysisOrigin;
  final bool activeAnalysisFollowsUser;

  /// An analysis is in flight — the map shows the web's pulsing ping and
  /// "Analyzing…" pill instead of blocking the screen.
  final bool analysisLoading;

  /// The analysis's dashed route to the nearest facility (the web's
  /// "Shortest Route") and that facility's name, for the "Route active"
  /// card. Null when no route could be found.
  final DirectionsRoute? analysisRoute;
  final String? analysisRouteName;

  /// The "Route active" card's ✕ — hides just the card, like the Go to
  /// Help one.
  final bool analysisRouteChipDismissed;
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

  /// Whether the top-left Route Planner input panel (free-form origin +
  /// destination search) is open. Closes itself once its "Get Directions"
  /// produces a route; closing it never cancels an active route.
  final bool showRoutePlanner;

  /// The point the active route leads to, and the route itself — non-null
  /// together for the whole "Go to Help"/Route Planner lifetime, matching
  /// the web platform's turn-by-turn card. Not necessarily a real
  /// [Facility]: the Route Planner's destination can be any searched place.
  final RoutePoint? goToHelpDestination;
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

  /// Set once live tracking reaches the destination — the card's "You
  /// have arrived" with how long the trip took since Start. Null otherwise.
  final int? goToHelpArrivedTripMinutes;

  /// Where the live position sits along [goToHelpRoute] — "to go" along
  /// the road, and where the driven part of the line ends. Null until the
  /// first fix, and while off route.
  final RouteProgress? goToHelpProgress;

  /// Live tracking has left the route (the web's 80 m, 3 fixes rule) — the
  /// card turns pink and offers Recalculate.
  final bool goToHelpOffRoute;

  /// The off-route status line ("Still off the route — recalculating
  /// automatically…", a failed recalculation, …).
  final String? goToHelpOffRouteNotice;
  final bool goToHelpRecalculating;

  /// Direction of travel while tracking (0° = north) — the GPS's, or from
  /// the last two fixes once they're 8 m apart. Turns the "You are here"
  /// cone, and the map when [goToHelpFollowHeading].
  final double? goToHelpHeading;

  /// The map rotates so the direction of travel points up — on from Start,
  /// toggled with the compass button, as on the web.
  final bool goToHelpFollowHeading;

  /// Whether spoken turn-by-turn instructions are on — matches the web
  /// platform's "Voice directions" toggle.
  final bool goToHelpVoiceEnabled;

  /// Whether the "Who do you need?" confirmation is showing, after tapping
  /// "Send SOS instead" — matches the web platform, which confirms before
  /// clearing the route and handing off into a ping.
  final bool goToHelpSosConfirming;

  /// Whether the card's "Close" has been tapped and is showing its "Stop
  /// routing and clear the map?" confirmation — matches the web platform's
  /// second chance before an active route is actually torn down.
  final bool goToHelpCloseConfirming;

  /// Whether the top-right "Route active" chip has been dismissed. Its X
  /// only hides the chip; ending the route is the card's (confirmed)
  /// Close. Reset whenever a new route starts.
  final bool routeChipDismissed;

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
    bool? analysisLoading,
    Object? analysisRoute = _unset,
    Object? analysisRouteName = _unset,
    bool? analysisRouteChipDismissed,
    bool? showAnalysisSheet,
    bool? showChangeModeCard,
    bool? showLegend,
    bool? showSosMenu,
    bool? showEmergencyFacilities,
    bool? showLiveTraffic,
    bool? showLagosBoundary,
    Object? lagosBoundary = _unset,
    int? analysisThresholdMinutes,
    Object? originSelection = _unset,
    Object? selectedFacility = _unset,
    bool? showGetHelpFast,
    bool? showRoutePlanner,
    Object? goToHelpDestination = _unset,
    Object? goToHelpRoute = _unset,
    bool? goToHelpCardExpanded,
    bool? goToHelpLoading,
    Object? goToHelpOrigin = _unset,
    bool? goToHelpFollowsUser,
    bool? goToHelpTracking,
    Object? goToHelpAccuracyMeters = _unset,
    Object? goToHelpArrivedTripMinutes = _unset,
    Object? goToHelpProgress = _unset,
    bool? goToHelpOffRoute,
    Object? goToHelpOffRouteNotice = _unset,
    bool? goToHelpRecalculating,
    Object? goToHelpHeading = _unset,
    bool? goToHelpFollowHeading,
    bool? goToHelpVoiceEnabled,
    bool? goToHelpSosConfirming,
    bool? goToHelpCloseConfirming,
    bool? routeChipDismissed,
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
      analysisLoading: analysisLoading ?? this.analysisLoading,
      analysisRoute: identical(analysisRoute, _unset)
          ? this.analysisRoute
          : analysisRoute as DirectionsRoute?,
      analysisRouteName: identical(analysisRouteName, _unset)
          ? this.analysisRouteName
          : analysisRouteName as String?,
      analysisRouteChipDismissed:
          analysisRouteChipDismissed ?? this.analysisRouteChipDismissed,
      showAnalysisSheet: showAnalysisSheet ?? this.showAnalysisSheet,
      showChangeModeCard: showChangeModeCard ?? this.showChangeModeCard,
      showLegend: showLegend ?? this.showLegend,
      showSosMenu: showSosMenu ?? this.showSosMenu,
      showEmergencyFacilities:
          showEmergencyFacilities ?? this.showEmergencyFacilities,
      showLiveTraffic: showLiveTraffic ?? this.showLiveTraffic,
      showLagosBoundary: showLagosBoundary ?? this.showLagosBoundary,
      lagosBoundary: identical(lagosBoundary, _unset)
          ? this.lagosBoundary
          : lagosBoundary as List<GeoPoint>?,
      analysisThresholdMinutes:
          analysisThresholdMinutes ?? this.analysisThresholdMinutes,
      originSelection: identical(originSelection, _unset)
          ? this.originSelection
          : originSelection as OriginSelection?,
      selectedFacility: identical(selectedFacility, _unset)
          ? this.selectedFacility
          : selectedFacility as Facility?,
      showGetHelpFast: showGetHelpFast ?? this.showGetHelpFast,
      showRoutePlanner: showRoutePlanner ?? this.showRoutePlanner,
      goToHelpDestination: identical(goToHelpDestination, _unset)
          ? this.goToHelpDestination
          : goToHelpDestination as RoutePoint?,
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
      goToHelpArrivedTripMinutes: identical(goToHelpArrivedTripMinutes, _unset)
          ? this.goToHelpArrivedTripMinutes
          : goToHelpArrivedTripMinutes as int?,
      goToHelpProgress: identical(goToHelpProgress, _unset)
          ? this.goToHelpProgress
          : goToHelpProgress as RouteProgress?,
      goToHelpOffRoute: goToHelpOffRoute ?? this.goToHelpOffRoute,
      goToHelpOffRouteNotice: identical(goToHelpOffRouteNotice, _unset)
          ? this.goToHelpOffRouteNotice
          : goToHelpOffRouteNotice as String?,
      goToHelpRecalculating:
          goToHelpRecalculating ?? this.goToHelpRecalculating,
      goToHelpHeading: identical(goToHelpHeading, _unset)
          ? this.goToHelpHeading
          : goToHelpHeading as double?,
      goToHelpFollowHeading:
          goToHelpFollowHeading ?? this.goToHelpFollowHeading,
      goToHelpVoiceEnabled: goToHelpVoiceEnabled ?? this.goToHelpVoiceEnabled,
      goToHelpSosConfirming:
          goToHelpSosConfirming ?? this.goToHelpSosConfirming,
      goToHelpCloseConfirming:
          goToHelpCloseConfirming ?? this.goToHelpCloseConfirming,
      routeChipDismissed: routeChipDismissed ?? this.routeChipDismissed,
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

  /// When Start was tapped, for the arrival card's trip time.
  DateTime? _trackingStartedAt;

  /// Off-route bookkeeping, as the web tracker: consecutive fixes off the
  /// line, automatic recalculations made, and the two timers that announce
  /// and then make one.
  int _offRouteStrikes = 0;
  int _autoRecalculations = 0;
  Timer? _offRouteNoticeTimer;
  Timer? _offRouteRecalcTimer;

  /// Route steps already announced, so each turn is said once (the web's
  /// spoken set) — cleared whenever the route changes.
  final Set<int> _spokenSteps = {};

  /// The last fix, for working out a heading the GPS didn't give.
  GeoPoint? _lastHeadingPoint;

  @override
  Future<HomeMapState> build() {
    ref.onDispose(() {
      _trackingSubscription?.cancel();
      _cancelOffRouteTimers();
    });
    return _load();
  }

  Future<HomeMapState> _load() async {
    final locationResult = await ref
        .read(locationRepositoryProvider)
        .currentPosition();
    final center = locationResult.position ?? defaultMapCenter;

    final facilityRepository = ref.read(facilityRepositoryProvider);
    final results = await (
      facilityRepository.allFacilities(),
      facilityRepository.boundary(),
    ).wait;
    final facilitiesResult = results.$1;
    final boundaryResult = results.$2;

    final facilities = switch (facilitiesResult) {
      Ok(:final value) => value,
      Err() => const <Facility>[],
    };
    // Silent on failure, unlike facilities — it's a decorative outline, not
    // core to the map being usable, so it's not worth alarming the user
    // over.
    final boundary = boundaryResult.valueOrNull;

    final locationMessage =
        locationResult.status == LocationAccessStatus.granted
        ? null
        : locationStatusMessage(locationResult.status);
    final facilitiesMessage = switch (facilitiesResult) {
      Ok() => null,
      Err(:final failure) => failure.userMessage,
    };

    // A ping still open from before this launch reopens the Get Help card
    // at its location; the card itself finds and resumes the ping.
    final activePing = await _openActivePing();

    return HomeMapState(
      facilities: facilities,
      center: activePing?.origin ?? center,
      locationStatus: locationResult.status,
      lagosBoundary: boundary,
      originSelection: activePing == null
          ? null
          : OriginSelection(
              point: activePing.origin,
              title: activePing.isPinned ? '📍 Dropped Pin' : 'Your Location',
              analyzeLabel: activePing.isPinned
                  ? 'Analyze Access Here'
                  : 'Analyze Access',
              followsUser: !activePing.isPinned,
            ),
      showGetHelpFast: activePing != null,
      // Location's own message takes priority when both fail — it's the
      // more fundamentally blocking of the two (no facilities is a broken
      // list; no location is a broken map).
      errorMessage: locationMessage ?? facilitiesMessage,
    );
  }

  /// The saved ping, if it's still open. One the server reports closed is
  /// forgotten here; one it can't be asked about (offline) is kept — the
  /// card's own polling will settle it once there's a connection.
  Future<ActivePing?> _openActivePing() async {
    if (isTestEnvironment) return null;
    final repository = ref.read(activePingRepositoryProvider);
    final ActivePing? stored;
    try {
      stored = await repository.load();
    } catch (_) {
      // Never let storage trouble take down the whole map load.
      return null;
    }
    if (stored == null) return null;
    final result = await ref
        .read(pingServiceProvider)
        .trackPing(stored.publicId);
    if (result case Ok(:final value) when value.incident.status.isClosed) {
      await repository.clear();
      return null;
    }
    return stored;
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

  void _log(String name, [Map<String, Object>? parameters]) =>
      ref.read(analyticsServiceProvider).logEvent(name, parameters: parameters);

  /// Adds to the signed-in account's dashboard activity, as the web does.
  /// Signed out there's no account to log against, and a failure isn't
  /// worth surfacing.
  void logInteraction(Facility facility, FacilityInteraction type) {
    if (ref.read(authViewModelProvider).value == null) return;
    unawaited(ref.read(interactionServiceProvider).log(facility, type));
  }

  void _logRouteStarted(String source, {FacilityCategory? category}) =>
      _log(AnalyticsEvents.routeStarted, {
        'source': source,
        'mode':
            (state.value?.selectedTransportMode ?? TransportMode.driving).name,
        'category': ?category?.name,
      });

  void _setError(String message) =>
      _update((s) => s.copyWith(errorMessage: message));

  void clearErrorMessage() => _update((s) => s.copyWith(errorMessage: null));

  void selectFilter(FacilityCategory? filter) =>
      _update((s) => s.copyWith(selectedFilter: filter));

  /// The analysis panel's "Facility type" pills — the same filter as the
  /// map's, and the analysis re-runs for that type at the same point, as
  /// on the web.
  Future<void> filterAnalysis(FacilityCategory? filter) async {
    selectFilter(filter);
    final current = state.value;
    final origin = current?.activeAnalysisOrigin;
    if (origin == null) return;
    await runAnalysis(origin, followsUser: current!.activeAnalysisFollowsUser);
  }

  /// Just switches the selected transport mode — used by the origin popup's
  /// mode picker before an analysis has been run. See [changeCommuteMode]
  /// for switching mode while an analysis is already active.
  void setSelectedMode(TransportMode mode) {
    if (state.value?.selectedTransportMode != mode) {
      _log(AnalyticsEvents.travelModeChanged, {'mode': mode.name});
    }
    _update((s) => s.copyWith(selectedTransportMode: mode));
  }

  /// Stops the live position stream backing "Start" tracking, if any —
  /// called whenever the Go to Help route itself is being torn down, so a
  /// stale subscription doesn't keep updating a route that's no longer
  /// shown.
  void _cancelTracking() {
    _trackingSubscription?.cancel();
    _trackingSubscription = null;
    _cancelOffRouteTimers();
    _offRouteStrikes = 0;
    _autoRecalculations = 0;
    _spokenSteps.clear();
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
        goToHelpArrivedTripMinutes: null,
        goToHelpProgress: null,
        goToHelpOffRoute: false,
        goToHelpOffRouteNotice: null,
        goToHelpRecalculating: false,
        goToHelpHeading: null,
        goToHelpFollowHeading: false,
        goToHelpSosConfirming: false,
      ),
    );
  }

  /// Selecting a facility always shows its marker — clears
  /// [HomeMapState.selectedFilter] so a category filter left on from
  /// before can't hide the thing just selected. Confirmed as a real bug:
  /// with a filter active, searching for and selecting a facility outside
  /// it flew the camera there and opened its popup, but its marker was
  /// filtered out of [MapAnnotationController.syncFacilityPins]'s render
  /// list the whole time.
  void selectFacility(Facility facility) {
    _log(AnalyticsEvents.facilityViewed, {'category': facility.category.name});
    _cancelTracking();
    _update(
      (s) => s.copyWith(
        selectedFacility: facility,
        selectedFilter: null,
        originSelection: null,
        showGetHelpFast: false,
        goToHelpDestination: null,
        goToHelpRoute: null,
        goToHelpOrigin: null,
        goToHelpFollowsUser: false,
        goToHelpTracking: false,
        goToHelpAccuracyMeters: null,
        goToHelpArrivedTripMinutes: null,
        goToHelpProgress: null,
        goToHelpOffRoute: false,
        goToHelpOffRouteNotice: null,
        goToHelpRecalculating: false,
        goToHelpHeading: null,
        goToHelpFollowHeading: false,
        goToHelpSosConfirming: false,
      ),
    );
  }

  /// A popup's own close button — closes just the facility / origin / Get
  /// Help Fast card. Unlike [clearPopups], leaves any active route, the
  /// Route Planner and the analysis alone: those are separate features
  /// with their own close controls.
  void closePopup() => _update(
    (s) => s.copyWith(
      originSelection: null,
      selectedFacility: null,
      showGetHelpFast: false,
    ),
  );

  /// Tears down every popup *and* the active route — for "start something
  /// new" transitions (running an analysis, the clear-map button), not for
  /// a single card's close button; that's [closePopup].
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
        goToHelpArrivedTripMinutes: null,
        goToHelpProgress: null,
        goToHelpOffRoute: false,
        goToHelpOffRouteNotice: null,
        goToHelpRecalculating: false,
        goToHelpHeading: null,
        goToHelpFollowHeading: false,
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

  /// The card's "Close" — asks first rather than ending the route outright.
  void requestCloseGoToHelp() =>
      _update((s) => s.copyWith(goToHelpCloseConfirming: true));

  /// "Keep route" — backs out of the close confirmation.
  void cancelCloseGoToHelp() =>
      _update((s) => s.copyWith(goToHelpCloseConfirming: false));

  /// The "Route active" chip's X — hides only the chip.
  void dismissRouteChip() =>
      _update((s) => s.copyWith(routeChipDismissed: true));

  /// Swaps the origin popup's content to "Get Help Fast," anchored at the
  /// same map point — matches the web platform, where this replaces the
  /// analyzer card in place rather than opening a separate sheet.
  void openGetHelpFast() => _update((s) => s.copyWith(showGetHelpFast: true));

  /// Swaps back to the origin popup (dropped pin or "Your Location") that
  /// "Get Help Fast" was opened from, without closing the popup entirely.
  void closeGetHelpFast() => _update((s) => s.copyWith(showGetHelpFast: false));

  void toggleRoutePlanner() {
    if (state.value?.showRoutePlanner == false) {
      _log(AnalyticsEvents.routePlannerOpened);
    }
    _update((s) => s.copyWith(showRoutePlanner: !s.showRoutePlanner));
  }

  void openRoutePlanner() {
    if (state.value?.showRoutePlanner == false) {
      _log(AnalyticsEvents.routePlannerOpened);
    }
    _update((s) => s.copyWith(showRoutePlanner: true));
  }

  void closeRoutePlanner() =>
      _update((s) => s.copyWith(showRoutePlanner: false));

  void toggleLegend() {
    final showing = state.value?.showLegend;
    if (showing != null) {
      _log(AnalyticsEvents.legendToggled, {'enabled': '${!showing}'});
    }
    _update((s) => s.copyWith(showLegend: !s.showLegend));
  }

  void toggleSosMenu() {
    if (state.value?.showSosMenu == false) _log(AnalyticsEvents.sosMenuOpened);
    _update((s) => s.copyWith(showSosMenu: !s.showSosMenu));
  }

  void closeSosMenu() => _update((s) => s.copyWith(showSosMenu: false));

  void dismissChangeModeCard() =>
      _update((s) => s.copyWith(showChangeModeCard: false));

  void toggleEmergencyFacilitiesLayer() => _update(
    (s) => s.copyWith(showEmergencyFacilities: !s.showEmergencyFacilities),
  );

  void toggleLiveTrafficLayer() {
    final showing = state.value?.showLiveTraffic;
    if (showing != null) {
      _log(AnalyticsEvents.liveTrafficToggled, {'enabled': '${!showing}'});
    }
    _update((s) => s.copyWith(showLiveTraffic: !s.showLiveTraffic));
  }

  void toggleLagosBoundaryLayer() =>
      _update((s) => s.copyWith(showLagosBoundary: !s.showLagosBoundary));

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
    _update(
      (s) => s.copyWith(
        analysisLoading: true,
        analysisRoute: null,
        analysisRouteName: null,
        analysisRouteChipDismissed: false,
      ),
    );
    final mode = state.value?.selectedTransportMode ?? TransportMode.driving;

    final AccessAnalysisResult result;
    switch (await ref
        .read(accessAnalysisRepositoryProvider)
        .analyze(
          origin: origin,
          mode: state.value?.selectedTransportMode ?? TransportMode.driving,
          thresholdMinutes:
              state.value?.analysisThresholdMinutes ??
              kAccessAnalysisThresholdMinutes,
          category: state.value?.selectedFilter,
        )) {
      case Ok(:final value):
        result = value;
      case Err(:final failure):
        _update((s) => s.copyWith(analysisLoading: false));
        _setError(failure.userMessage);
        return;
    }

    final (route: nearestRoute, name: nearestName) = await _routeToNearest(
      origin,
      mode,
    );

    _log(AnalyticsEvents.accessAnalysisRun, {
      'mode':
          (state.value?.selectedTransportMode ?? TransportMode.driving).name,
      'threshold_minutes':
          state.value?.analysisThresholdMinutes ??
          kAccessAnalysisThresholdMinutes,
    });
    _update(
      (s) => s.copyWith(
        activeAnalysis: result,
        activeAnalysisOrigin: origin,
        activeAnalysisFollowsUser: followsUser,
        analysisLoading: false,
        analysisRoute: nearestRoute,
        analysisRouteName: nearestName,
        showChangeModeCard: true,
        showAnalysisSheet: openSheet ? true : s.showAnalysisSheet,
      ),
    );
  }

  /// The web's analysis also routes to the nearest facility — by straight
  /// line, among the facilities the current filter shows — and draws that
  /// route dashed. A failure only costs the route, never the analysis; the
  /// messages are the web's.
  Future<({DirectionsRoute? route, String? name})> _routeToNearest(
    GeoPoint origin,
    TransportMode mode,
  ) async {
    final filter = state.value?.selectedFilter;
    Facility? nearest;
    var nearestDistance = double.infinity;
    for (final facility in state.value?.facilities ?? const <Facility>[]) {
      if (filter != null && facility.category != filter) continue;
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
    if (nearest == null) return (route: null, name: null);

    final result = await ref
        .read(accessAnalysisServiceProvider)
        .fetchRoute(
          origin: origin,
          destination: GeoPoint(
            latitude: nearest.latitude,
            longitude: nearest.longitude,
          ),
          mode: mode,
        );
    switch (result) {
      case Ok(:final value):
        return (route: value, name: nearest.name);
      case Err(failure: NetworkFailure() || TimeoutFailure()):
        _setError(
          'Could not calculate a route. Check your connection and try again.',
        );
      case Err():
        _setError(switch (mode) {
          TransportMode.walking =>
            'That facility is too far to walk to. Try Car or Motorcycle.',
          TransportMode.cycling =>
            'That facility is too far to cycle to. Try Car or Motorcycle.',
          _ => 'No route could be found to the nearest facility.',
        });
    }
    return (route: null, name: null);
  }

  void dismissAnalysisRouteChip() =>
      _update((s) => s.copyWith(analysisRouteChipDismissed: true));

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
        analysisRoute: null,
        analysisRouteName: null,
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
    switch (await ref
        .read(accessAnalysisServiceProvider)
        .fetchRoute(
          origin: origin,
          destination: destination,
          mode: state.value?.selectedTransportMode ?? TransportMode.driving,
        )) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        _setError(failure.userMessage);
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

    final destination = RoutePoint.fromFacility(nearest);
    _logRouteStarted('get_help', category: category);
    logInteraction(nearest, FacilityInteraction.navigated);
    _update(
      (s) => s.copyWith(
        goToHelpDestination: destination,
        goToHelpArrivedTripMinutes: null,
        goToHelpProgress: null,
        goToHelpOffRoute: false,
        goToHelpOffRouteNotice: null,
        goToHelpRecalculating: false,
        goToHelpHeading: null,
        goToHelpFollowHeading: false,
        goToHelpRoute: route,
        goToHelpCardExpanded: true,
        goToHelpCloseConfirming: false,
        routeChipDismissed: false,
        goToHelpLoading: false,
        goToHelpOrigin: origin,
        goToHelpFollowsUser: originSelection.followsUser,
        showGetHelpFast: false,
        originSelection: null,
        selectedFacility: null,
      ),
    );
  }

  /// A Triage routing button ("Show nearest …" / "Navigate to …" /
  /// "Also: …") — the web's `onNavigateTo`: clear whatever is on the map,
  /// take a live GPS fix, pick the facility the way the web does (see
  /// [pickTriageFacility]) and route there from the user's position.
  ///
  /// Returns `false` when there's no GPS fix; like the web, the caller then
  /// opens the Route Planner so the user can pick a start point instead.
  Future<bool> startTriageRoute(TriageNavigation navigation) async {
    clearPopups();
    _update(
      (s) => s.copyWith(
        activeAnalysis: null,
        activeAnalysisOrigin: null,
        activeAnalysisFollowsUser: false,
        showAnalysisSheet: false,
        showRoutePlanner: false,
        goToHelpCloseConfirming: false,
        routeChipDismissed: false,
        goToHelpLoading: true,
      ),
    );

    final location = await ref
        .read(locationRepositoryProvider)
        .currentPosition();
    final origin = location.position;
    if (origin == null) {
      _update(
        (s) => s.copyWith(
          goToHelpLoading: false,
          showRoutePlanner: true,
          // The web opens the planner silently; saying why avoids it
          // looking like the button did the wrong thing.
          errorMessage:
              "Couldn't get your location — choose a starting point to "
              'get directions.',
        ),
      );
      return false;
    }

    final facility = pickTriageFacility(
      facilities: state.value?.facilities ?? const <Facility>[],
      origin: origin,
      category: navigation.category,
      department: navigation.department,
      isEmergency: navigation.isEmergency,
    );
    if (facility == null) {
      _update((s) => s.copyWith(goToHelpLoading: false));
      _setError('No nearby ${navigation.category.displayLabel} found');
      return true;
    }
    await startGoToHelpToFacility(
      facility,
      origin: origin,
      followsUser: true,
      analyticsSource: 'triage',
    );
    return true;
  }

  /// Routes to [facility] directly, skipping the "nearest of category"
  /// search [startGoToHelp] does — used when the destination is already
  /// chosen, e.g. "Map Route" on a specific facility row in the Access
  /// Analysis sheet. Takes an explicit [origin]/[followsUser] rather than
  /// reading [HomeMapState.originSelection] the way [startGoToHelp] does:
  /// by the time this is called that popup is usually already gone, since
  /// the analysis sheet tracks its own origin separately (see
  /// [resolveRouteOrigin]).
  Future<void> startGoToHelpToFacility(
    Facility facility, {
    required GeoPoint origin,
    required bool followsUser,
    String analyticsSource = 'facility',
  }) async {
    _update((s) => s.copyWith(goToHelpLoading: true));
    final route = await fetchRoute(
      origin,
      GeoPoint(latitude: facility.latitude, longitude: facility.longitude),
    );
    if (route == null) {
      _update((s) => s.copyWith(goToHelpLoading: false));
      return;
    }

    _logRouteStarted(analyticsSource, category: facility.category);
    logInteraction(facility, FacilityInteraction.navigated);
    _update(
      (s) => s.copyWith(
        goToHelpDestination: RoutePoint.fromFacility(facility),
        goToHelpArrivedTripMinutes: null,
        goToHelpProgress: null,
        goToHelpOffRoute: false,
        goToHelpOffRouteNotice: null,
        goToHelpRecalculating: false,
        goToHelpHeading: null,
        goToHelpFollowHeading: false,
        goToHelpRoute: route,
        goToHelpCardExpanded: true,
        goToHelpCloseConfirming: false,
        routeChipDismissed: false,
        goToHelpLoading: false,
        goToHelpOrigin: origin,
        goToHelpFollowsUser: followsUser,
        showGetHelpFast: false,
        originSelection: null,
        selectedFacility: null,
        activeAnalysis: null,
        activeAnalysisOrigin: null,
        activeAnalysisFollowsUser: false,
        showAnalysisSheet: false,
      ),
    );
  }

  /// The Route Planner's "Get Directions" — unlike every other Go to Help
  /// entry point, both ends are arbitrary [RoutePoint]s (a searched place,
  /// a known facility, or the user's current location), not a fixed
  /// facility destination from a fixed origin. [originFollowsUser] mirrors
  /// [startGoToHelp]'s live-GPS handling: when the planner's origin was
  /// "Use Current Location" rather than a searched point, this re-fetches
  /// a fresh fix instead of trusting [origin]'s (possibly now-stale) one.
  Future<void> startRoutePlan({
    required RoutePoint origin,
    required RoutePoint destination,
    required bool originFollowsUser,
  }) async {
    var originPoint = origin.point;
    if (originFollowsUser) {
      final result = await ref
          .read(locationRepositoryProvider)
          .currentPosition();
      originPoint = result.position ?? originPoint;
    }

    _update((s) => s.copyWith(goToHelpLoading: true));
    final route = await fetchRoute(originPoint, destination.point);
    if (route == null) {
      _update((s) => s.copyWith(goToHelpLoading: false));
      return;
    }

    _logRouteStarted('route_planner');
    // Only a facility destination — a dropped pin or searched place isn't
    // dashboard activity.
    final facilities = state.value?.facilities ?? const <Facility>[];
    for (final facility in facilities) {
      if (facility.name == destination.name) {
        logInteraction(facility, FacilityInteraction.navigated);
        break;
      }
    }
    _update(
      (s) => s.copyWith(
        goToHelpDestination: destination,
        goToHelpArrivedTripMinutes: null,
        goToHelpProgress: null,
        goToHelpOffRoute: false,
        goToHelpOffRouteNotice: null,
        goToHelpRecalculating: false,
        goToHelpHeading: null,
        goToHelpFollowHeading: false,
        goToHelpRoute: route,
        goToHelpCardExpanded: true,
        goToHelpCloseConfirming: false,
        routeChipDismissed: false,
        goToHelpLoading: false,
        goToHelpOrigin: originPoint,
        goToHelpFollowsUser: originFollowsUser,
        showGetHelpFast: false,
        // The planner's job is done once a route exists — only closed on
        // success, so a failed fetch leaves its inputs there to retry.
        showRoutePlanner: false,
        originSelection: null,
        selectedFacility: null,
        activeAnalysis: null,
        activeAnalysisOrigin: null,
        activeAnalysisFollowsUser: false,
        showAnalysisSheet: false,
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
        // Progress (and which turns were said) is along the old line; the
        // next fix finds it again.
        goToHelpProgress: route == null ? s.goToHelpProgress : null,
        goToHelpOrigin: origin,
        goToHelpLoading: false,
      ),
    );
    if (route != null) _spokenSteps.clear();
  }

  void toggleGoToHelpCard() =>
      _update((s) => s.copyWith(goToHelpCardExpanded: !s.goToHelpCardExpanded));

  /// Cancels the active Go to Help route entirely — matches the web
  /// platform's "Route active" chip close button.
  void closeGoToHelp() {
    _log(AnalyticsEvents.routeCleared);
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
        goToHelpArrivedTripMinutes: null,
        goToHelpProgress: null,
        goToHelpOffRoute: false,
        goToHelpOffRouteNotice: null,
        goToHelpRecalculating: false,
        goToHelpHeading: null,
        goToHelpFollowHeading: false,
        goToHelpSosConfirming: false,
        goToHelpCloseConfirming: false,
        routeChipDismissed: false,
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
    _log(AnalyticsEvents.routeNavigationStarted);
    _cancelTracking();
    _trackingStartedAt = DateTime.now();
    _lastHeadingPoint = null;
    _update(
      (s) => s.copyWith(
        goToHelpTracking: true,
        goToHelpArrivedTripMinutes: null,
        goToHelpAccuracyMeters: null,
        goToHelpHeading: null,
        // The web turns the map with you as soon as you press Start.
        goToHelpFollowHeading: true,
      ),
    );
    _trackingSubscription = ref
        .read(locationRepositoryProvider)
        .positionStream()
        .listen(_onTrackedPosition);
  }

  /// Stops live tracking and reverts to the static route preview — the web
  /// platform's "Stop." Leaves the route itself (destination, last-known
  /// path) in place, unlike [closeGoToHelp].
  void stopGoToHelpTracking() {
    _cancelTracking();
    _update(
      (s) => s.copyWith(
        goToHelpTracking: false,
        goToHelpProgress: null,
        goToHelpOffRoute: false,
        goToHelpOffRouteNotice: null,
        goToHelpHeading: null,
        goToHelpFollowHeading: false,
      ),
    );
  }

  /// Follows each live GPS fix along the route, as the web tracker does:
  /// progress and "to go" along the road, arrival, and off-route detection.
  /// The route itself is only re-fetched to recalculate after leaving it.
  Future<void> _onTrackedPosition(TrackedPosition tracked) async {
    final destination = state.value?.goToHelpDestination;
    if (destination == null) {
      stopGoToHelpTracking();
      return;
    }

    // The GPS's heading, else the direction from the last fix once it's
    // more than 8 m away; otherwise keep the last known one.
    final last = _lastHeadingPoint;
    final heading =
        tracked.headingDegrees ??
        (last != null && haversineMeters(last, tracked.point) > 8
            ? bearingDegrees(last, tracked.point)
            : null);
    _lastHeadingPoint = tracked.point;
    _update(
      (s) => s.copyWith(
        goToHelpOrigin: tracked.point,
        goToHelpAccuracyMeters: tracked.accuracyMeters,
        goToHelpHeading: heading ?? s.goToHelpHeading,
      ),
    );

    // The web's arrival rule: within 60 m, widened to the fix's accuracy
    // when GPS is poor, but never beyond 150 m.
    final distance = Geolocator.distanceBetween(
      tracked.point.latitude,
      tracked.point.longitude,
      destination.latitude,
      destination.longitude,
    );
    if (distance <= max(60, min(tracked.accuracyMeters, 150))) {
      _arrive(destination);
      return;
    }

    final route = state.value?.goToHelpRoute;
    if (route == null || route.points.isEmpty) return;

    _announceNextTurn(tracked.point);

    // Off route: further than 80 m from the line (plus up to 100 m for a
    // poor fix) on 3 fixes in a row.
    final off =
        distanceToLine(tracked.point, route.points) >
        80 + min(tracked.accuracyMeters, 100);
    if (off) {
      _offRouteStrikes++;
      if (_offRouteStrikes >= 3 && !(state.value?.goToHelpOffRoute ?? true)) {
        _enterOffRoute();
      }
      return;
    }
    _offRouteStrikes = 0;
    if (state.value?.goToHelpOffRoute ?? false) _leaveOffRoute();

    // Progress only moves forward along the line.
    final previous = state.value?.goToHelpProgress;
    final progress = progressAlong(
      tracked.point,
      route.points,
      fromIndex: previous?.segmentIndex ?? 0,
    );
    if (progress != null &&
        (previous == null || progress.segmentIndex >= previous.segmentIndex)) {
      _update((s) => s.copyWith(goToHelpProgress: progress));
    }
  }

  void _enterOffRoute() {
    _update(
      (s) => s.copyWith(
        goToHelpOffRoute: true,
        goToHelpProgress: null,
        goToHelpOffRouteNotice: _autoRecalculations >= 3
            ? 'Still off the route. Tap Recalculate when you have signal.'
            : null,
      ),
    );
    _speak('You have left the route');
    if (_autoRecalculations >= 3) return;
    _offRouteNoticeTimer = Timer(const Duration(seconds: 12), () {
      _update(
        (s) => s.copyWith(
          goToHelpOffRouteNotice:
              'Still off the route — recalculating automatically…',
        ),
      );
      _speak('You are still off the route. Recalculating shortly.');
    });
    _offRouteRecalcTimer = Timer(const Duration(seconds: 24), () {
      _autoRecalculations++;
      unawaited(recalculateGoToHelpRoute(automatic: true));
    });
  }

  void _leaveOffRoute() {
    _cancelOffRouteTimers();
    _autoRecalculations = 0;
    _update(
      (s) => s.copyWith(goToHelpOffRoute: false, goToHelpOffRouteNotice: null),
    );
  }

  void _cancelOffRouteTimers() {
    _offRouteNoticeTimer?.cancel();
    _offRouteNoticeTimer = null;
    _offRouteRecalcTimer?.cancel();
    _offRouteRecalcTimer = null;
  }

  /// The off-route card's "Recalculate route" — or the automatic one 24 s
  /// after leaving the route. A new route from the live position.
  Future<void> recalculateGoToHelpRoute({bool automatic = false}) async {
    final current = state.value;
    final origin = current?.goToHelpOrigin;
    final destination = current?.goToHelpDestination;
    if (origin == null ||
        destination == null ||
        current!.goToHelpRecalculating) {
      return;
    }
    _cancelOffRouteTimers();
    if (automatic) _speak('Recalculating your route');
    _update(
      (s) => s.copyWith(
        goToHelpRecalculating: true,
        goToHelpOffRouteNotice: automatic ? 'Recalculating…' : null,
      ),
    );
    final route = await fetchRoute(origin, destination.point);
    if (route == null) {
      _update(
        (s) => s.copyWith(
          goToHelpRecalculating: false,
          goToHelpOffRouteNotice: 'Could not recalculate — no route returned.',
        ),
      );
      return;
    }
    _offRouteStrikes = 0;
    if (!automatic) _autoRecalculations = 0;
    _update(
      (s) => s.copyWith(
        goToHelpRoute: route,
        goToHelpRecalculating: false,
        goToHelpOffRoute: false,
        goToHelpOffRouteNotice: null,
        goToHelpProgress: null,
      ),
    );
    _spokenSteps.clear();
    _announceNextTurn(origin);
  }

  /// Says [text] when voice directions are on.
  void _speak(String text) {
    if (!(state.value?.goToHelpVoiceEnabled ?? false)) return;
    unawaited(ref.read(voiceDirectionsServiceProvider).speak(text));
  }

  /// Live tracking reached [destination]: stop following, show "You have
  /// arrived" with the trip time, say so when voice is on, and record it
  /// on the account — once per trip, as on the web.
  void _arrive(RoutePoint destination) {
    _cancelTracking();
    final started = _trackingStartedAt ?? DateTime.now();
    final minutes = max(
      1,
      (DateTime.now().difference(started).inSeconds / 60).round(),
    );
    _update(
      (s) => s.copyWith(
        goToHelpTracking: false,
        goToHelpArrivedTripMinutes: minutes,
      ),
    );
    _log(AnalyticsEvents.routeArrived, {'trip_minutes': minutes});
    if (state.value?.goToHelpVoiceEnabled ?? false) {
      unawaited(
        ref
            .read(voiceDirectionsServiceProvider)
            .speak('You have arrived at ${destination.name}'),
      );
    }
    for (final facility in state.value?.facilities ?? const <Facility>[]) {
      if (facility.name == destination.name) {
        logInteraction(facility, FacilityInteraction.arrived);
        break;
      }
    }
  }

  /// The compass button's follow-your-direction mode.
  void setFollowHeading(bool follow) =>
      _update((s) => s.copyWith(goToHelpFollowHeading: follow));

  /// Turns spoken turn-by-turn instructions on/off — the web platform's
  /// "Voice directions" toggle. Turning it on mid-route checks for a turn
  /// to announce straight away, as the web does.
  void toggleGoToHelpVoice() {
    final enabling = !(state.value?.goToHelpVoiceEnabled ?? false);
    _log(AnalyticsEvents.voiceGuidanceToggled, {'enabled': '$enabling'});
    _update((s) => s.copyWith(goToHelpVoiceEnabled: enabling));
    if (!enabling) {
      unawaited(ref.read(voiceDirectionsServiceProvider).stop());
      return;
    }
    final origin = state.value?.goToHelpOrigin;
    if ((state.value?.goToHelpTracking ?? false) && origin != null) {
      _announceNextTurn(origin);
    }
  }

  /// Says the next turn once it's within 160 m of [position] — "In 150
  /// metres, turn left onto …", or just the instruction when close. Each
  /// turn is announced once; see [nextTurnAnnouncement].
  void _announceNextTurn(GeoPoint position) {
    final current = state.value;
    final route = current?.goToHelpRoute;
    if (route == null || !(current?.goToHelpVoiceEnabled ?? false)) return;
    final text = nextTurnAnnouncement(
      steps: route.steps,
      position: position,
      spoken: _spokenSteps,
    );
    if (text != null) _speak(text);
  }
}

final homeMapViewModelProvider =
    AsyncNotifierProvider<HomeMapViewModel, HomeMapState>(HomeMapViewModel.new);
