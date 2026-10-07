import 'ping.dart';

/// Which classifier produced a [TriageAssessment] — `local` is the keyword
/// fallback used when the AI is unavailable, and per the API docs is
/// "noticeably blunter," worth surfacing to the user rather than hiding.
enum TriageSource {
  ai,
  local;

  static TriageSource fromApi(String value) => switch (value) {
    'local' => TriageSource.local,
    _ => TriageSource.ai,
  };
}

/// The result of `POST /api/triage_symptoms`.
class TriageAssessment {
  const TriageAssessment({
    required this.source,
    required this.agency,
    required this.department,
    required this.isEmergency,
    required this.urgency,
    required this.sensitive,
    required this.message,
    this.secondaryAgency,
  });

  final TriageSource source;

  /// Null when the backend returned an agency string this app doesn't
  /// recognize — routing buttons are hidden rather than guessing.
  final PingAgency? agency;

  /// Null on at least the local-classifier fallback path (confirmed live:
  /// a `fallback_reason: "ai_error"` response came back with `department`
  /// as JSON `null`, not just an absent key) — the keyword classifier only
  /// determines an [agency], not a specific department within it.
  final String? department;

  final PingAgency? secondaryAgency;

  /// Drives facility selection: an emergency must never be routed to a
  /// pharmacy, laboratory, dental/eye clinic, or health post — none of
  /// them can admit a patient. The backend already enforces this for
  /// [department], and since this app only ever routes by [agency] (the
  /// coarse category), not the specific department, that guard holds
  /// automatically here.
  final bool isEmergency;

  final String urgency;

  /// A topic needing careful handling — show support options, not routing.
  final bool sensitive;

  final String message;
}
