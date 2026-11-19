import '../network/json_reader.dart';
import 'geo_point.dart';
import 'ping.dart';

/// A signed-in responder, as `/api/responder/login` and `/status` return
/// them.
class Responder {
  const Responder({
    required this.responderId,
    required this.fullName,
    required this.agency,
    this.stationName,
    this.phone,
    this.onDuty = false,
  });

  factory Responder.fromJson(JsonReader r) => Responder(
    responderId: r.string('responder_id'),
    fullName: r.stringOrNull('full_name') ?? r.string('responder_id'),
    agency: r.stringOrNull('agency') ?? '',
    stationName: r.stringOrNull('station_name'),
    phone: r.stringOrNull('phone'),
    onDuty: r.boolOr('on_duty', fallback: false),
  );

  final String responderId;
  final String fullName;

  /// The backend's agency string, e.g. `Police` — see [PingAgencyApi].
  final String agency;
  final String? stationName;
  final String? phone;
  final bool onDuty;

  PingAgency? get pingAgency => PingAgencyApi.fromApi(agency);

  /// The web console's agency icon.
  String get agencyIcon => switch (pingAgency) {
    PingAgency.health => '🏥',
    PingAgency.police => '🛡️',
    PingAgency.fire => '🔥',
    PingAgency.roadSafety => '🚧',
    null => '🚨',
  };

  Responder copyWith({bool? onDuty}) => Responder(
    responderId: responderId,
    fullName: fullName,
    agency: agency,
    stationName: stationName,
    phone: phone,
    onDuty: onDuty ?? this.onDuty,
  );
}

/// One ping in a responder's dispatch queue (`/api/responder/pings`):
/// an unclaimed one for their agency, or one they've accepted.
class ResponderPing {
  const ResponderPing({
    required this.id,
    required this.publicId,
    required this.status,
    required this.agency,
    required this.userPoint,
    this.userAccuracy,
    this.address,
    this.note,
    this.medicalProfile,
    this.hasVoice = false,
    this.voiceSeconds,
    this.responderId,
    this.responderMode,
    this.createdAt,
    this.acceptedAt,
    this.userEmail,
  });

  factory ResponderPing.fromJson(JsonReader r) => ResponderPing(
    id: r.int_('id'),
    publicId: r.stringOrNull('public_id') ?? '',
    status: PingStatus.fromApi(r.stringOrNull('status') ?? 'pending'),
    agency: r.stringOrNull('agency') ?? '',
    // History entries may leave the position out; the queue always has it.
    userPoint: GeoPoint(
      latitude: r.doubleOrNull('user_lat') ?? 0,
      longitude: r.doubleOrNull('user_lng') ?? 0,
    ),
    userAccuracy: r.doubleOrNull('user_accuracy'),
    address: r.stringOrNull('user_address'),
    note: r.stringOrNull('note'),
    medicalProfile: r.stringOrNull('medical_profile'),
    hasVoice: r.boolOr('has_voice', fallback: false),
    voiceSeconds: r.doubleOrNull('voice_seconds'),
    responderId: r.stringOrNull('responder_id'),
    responderMode: r.stringOrNull('responder_mode'),
    createdAt: DateTime.tryParse(r.stringOrNull('created_at') ?? ''),
    acceptedAt: DateTime.tryParse(r.stringOrNull('accepted_at') ?? ''),
    userEmail: r.stringOrNull('user_email'),
  );

  /// The incident number the responder endpoints take.
  final int id;

  /// The citizen's credential for this ping — also the voice note's token.
  final String publicId;
  final PingStatus status;
  final String agency;
  final GeoPoint userPoint;
  final double? userAccuracy;
  final String? address;

  /// The citizen's note, or their voice note's transcript.
  final String? note;

  /// Deleted by the server once the ping closes.
  final String? medicalProfile;
  final bool hasVoice;
  final double? voiceSeconds;
  final String? responderId;

  /// The backend's travel mode (`driving`, `biking`, `cycling`, `walking`).
  final String? responderMode;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final String? userEmail;

  bool get isPending => status == PingStatus.pending;

  /// Accepted by someone — in the queue, that's this responder.
  bool get isClaimed => responderId != null;

  /// Still being handled: the steps that can still be taken.
  bool get isActive => const {
    PingStatus.accepted,
    PingStatus.enRoute,
    PingStatus.arrived,
  }.contains(status);
}

/// `/api/responder/history`: past incidents and totals. Medical profiles
/// and recordings aren't included — the server deletes them on close.
class ResponderHistory {
  const ResponderHistory({
    required this.entries,
    required this.total,
    required this.resolved,
    this.avgAcceptSeconds,
  });

  factory ResponderHistory.fromJson(JsonReader r) {
    final stats = r.objectOrNull('stats');
    final entries = r.list('history', ResponderPing.fromJson);
    return ResponderHistory(
      entries: entries,
      total: stats?.intOrNull('total') ?? entries.length,
      resolved:
          stats?.intOrNull('resolved') ??
          entries.where((e) => e.status == PingStatus.resolved).length,
      avgAcceptSeconds: stats?.doubleOrNull('avg_accept_secs'),
    );
  }

  final List<ResponderPing> entries;
  final int total;
  final int resolved;
  final double? avgAcceptSeconds;
}

extension ResponderPingTiming on ResponderPing {
  /// How long the ping waited to be accepted, or null if it never was.
  Duration? get acceptDelay {
    final created = createdAt;
    final accepted = acceptedAt;
    if (created == null || accepted == null) return null;
    return accepted.difference(created);
  }
}

/// The web's "35s" or "2m 5s".
String formatAcceptDelay(Duration delay) {
  final seconds = delay.inSeconds;
  if (seconds < 60) return '${seconds}s';
  return '${seconds ~/ 60}m ${seconds % 60}s';
}
