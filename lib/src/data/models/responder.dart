import '../network/json_reader.dart';
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
