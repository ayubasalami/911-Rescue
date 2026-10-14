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

  /// Param: `source` = `drawer` | `route_planner`.
  static const searchResultSelected = 'search_result_selected';

  /// Params: `source` = `get_help` | `facility` | `route_planner`, `mode`,
  /// and `category` when the destination is a facility type.
  static const routeStarted = 'route_started';

  /// "Start" — live tracking along the route.
  static const routeNavigationStarted = 'route_navigation_started';
  static const routeCleared = 'route_cleared';

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
  static const triageChatOpened = 'triage_chat_opened';

  /// Params: `action` = `ping` | `go_to_help`, `category`.
  static const triageHandoff = 'triage_handoff';
}
