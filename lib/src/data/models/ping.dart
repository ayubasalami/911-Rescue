import 'geo_point.dart';

/// One of the four values `POST /api/ping`'s `agency` field accepts —
/// matches the backend's exact spelling, not the app's own
/// [FacilityCategory] grouping.
enum PingAgency { health, police, fire, roadSafety }

extension PingAgencyApi on PingAgency {
  /// The exact string the backend expects/returns.
  String get apiValue => switch (this) {
    PingAgency.health => 'Health Facilities',
    PingAgency.police => 'Police',
    PingAgency.fire => 'Fire & Emergency',
    PingAgency.roadSafety => 'Road Safety',
  };
}

/// The result of `POST /api/ping`.
class PingCreated {
  const PingCreated({
    required this.publicId,
    required this.respondersAvailable,
    required this.timeoutMinutes,
    this.alreadyActive = false,
  });

  /// The only credential for this ping — no account is required to raise
  /// one, so this is how tracking, correcting and cancelling it all work.
  /// Persist it locally so an app restart mid-emergency doesn't lose the
  /// ping.
  final String publicId;

  /// 0 means nobody is on duty for the requested agency right now — tell
  /// the user immediately and point them at 112 rather than letting them
  /// wait out [timeoutMinutes].
  final int respondersAvailable;

  final int timeoutMinutes;

  /// True when the caller (if signed in) already had an open ping and this
  /// is that existing one, not a new one.
  final bool alreadyActive;
}

enum PingStatus {
  pending,
  accepted,
  enRoute,
  arrived,
  resolved,
  cancelled,
  expired;

  static PingStatus fromApi(String value) => switch (value) {
    'pending' => PingStatus.pending,
    'accepted' => PingStatus.accepted,
    'en_route' => PingStatus.enRoute,
    'arrived' => PingStatus.arrived,
    'resolved' => PingStatus.resolved,
    'cancelled' => PingStatus.cancelled,
    'expired' => PingStatus.expired,
    _ => PingStatus.pending,
  };

  /// Once true, the ping is done — polling should stop.
  bool get isClosed => this == resolved || this == cancelled || this == expired;
}

class PingIncident {
  const PingIncident({
    required this.id,
    required this.status,
    required this.agency,
    required this.userPoint,
    this.userAddress,
    this.responderMode,
    this.note,
    this.hasVoice = false,
  });

  final int id;
  final PingStatus status;
  final String agency;
  final GeoPoint userPoint;
  final String? userAddress;

  /// How the assigned responder is travelling ("biking", "driving", …) —
  /// use this (not an assumed mode) when drawing the responder's route, a
  /// wrong assumption gives the wrong roads and ETA.
  final String? responderMode;
  final String? note;
  final bool hasVoice;
}

class PingResponder {
  const PingResponder({
    required this.responderId,
    required this.fullName,
    this.phone,
    this.stationName,
    this.lastPoint,
    this.lastAccuracy,
    this.lastSeen,
  });

  final String responderId;
  final String fullName;
  final String? phone;
  final String? stationName;
  final GeoPoint? lastPoint;
  final double? lastAccuracy;
  final DateTime? lastSeen;
}

/// The result of `GET /api/ping/{public_id}` — [responder] is null until
/// one accepts.
class PingTrackingInfo {
  const PingTrackingInfo({required this.incident, this.responder});

  final PingIncident incident;
  final PingResponder? responder;
}

/// The result of `POST /api/ping/{id}/voice`.
class VoiceUploadResult {
  const VoiceUploadResult({
    required this.transcript,
    required this.transcribed,
  });

  final String? transcript;

  /// False when the upload succeeded but transcription itself failed —
  /// the recording is still attached to the incident either way.
  final bool transcribed;
}
