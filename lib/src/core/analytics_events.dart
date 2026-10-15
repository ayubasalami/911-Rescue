/// Every Analytics event name in one place so call sites can't drift or
/// typo.
///
/// Parameters never carry coordinates, addresses, place names or search
/// text — someone's location during an emergency is sensitive. Categories,
/// travel modes, sources and on/off flags only.
abstract final class AnalyticsEvents {
  /// Param: `source` = `sos_menu` | `triage` | `get_help` | `go_to_help`.
  static const call112 = 'call_112';
  static const sosMenuOpened = 'sos_menu_opened';

  /// Param: `agency`.
  static const pingCreated = 'ping_created';

  /// Params: `agency`, `failure`.
  static const pingFailed = 'ping_failed';
  static const pingCancelled = 'ping_cancelled';

  /// A ping raised before an app restart (or before its card was closed)
  /// picked up again.
  static const pingResumed = 'ping_resumed';
  static const pingVoiceNoteSent = 'ping_voice_note_sent';

  /// Param: `category`.
  static const facilityViewed = 'facility_viewed';

  /// Params: `saved` (`true` / `false`), `category`.
  static const facilitySaved = 'facility_saved';

  /// Param: `source` = `drawer` | `route_planner`.
  static const searchResultSelected = 'search_result_selected';

  /// Params: `source` = `get_help` | `facility` | `route_planner` |
  /// `triage`, `mode`,
  /// and `category` when the destination is a facility type.
  static const routeStarted = 'route_started';

  /// "Start" — live tracking along the route.
  static const routeNavigationStarted = 'route_navigation_started';
  static const routeCleared = 'route_cleared';

  /// Live tracking reached the destination. Param: `trip_minutes`.
  static const routeArrived = 'route_arrived';

  /// Param: `enabled`.
  static const voiceGuidanceToggled = 'voice_guidance_toggled';
  static const routePlannerOpened = 'route_planner_opened';

  /// Params: `mode`, `threshold_minutes`.
  static const accessAnalysisRun = 'access_analysis_run';

  /// Param: `mode`.
  static const travelModeChanged = 'travel_mode_changed';

  /// Param: `enabled`.
  static const liveTrafficToggled = 'live_traffic_toggled';

  /// Param: `enabled`.
  static const legendToggled = 'legend_toggled';

  /// Param: `theme` (`light` / `dark`).
  static const themeToggled = 'theme_toggled';

  /// Firebase's standard sign-in event. Param: `method` (`google`).
  static const login = 'login';
  static const logout = 'logout';

  /// Param: `reason` = `google` (Google's own sign-in failed) | `rejected`
  /// (backend 401) | `google_unreachable` (backend 503) | `network` |
  /// `server`.
  static const loginFailed = 'login_failed';

  /// Param: `action` = `view` (a row tap) | `navigate` | `remove`.
  static const dashboardAction = 'dashboard_action';
  static const triageChatOpened = 'triage_chat_opened';

  /// A Triage routing button. Params: `category`, `emergency`.
  static const triageHandoff = 'triage_handoff';
}
