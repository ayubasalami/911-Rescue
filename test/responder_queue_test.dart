import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/core/app_failure.dart';
import 'package:rescue_911/src/core/result.dart';
import 'package:rescue_911/src/data/models/geo_point.dart';
import 'package:rescue_911/src/data/models/ping.dart';
import 'package:rescue_911/src/data/models/responder.dart';
import 'package:rescue_911/src/data/network/api_client.dart';
import 'package:rescue_911/src/data/network/json_reader.dart';
import 'package:rescue_911/src/data/services/responder_service.dart';
import 'package:rescue_911/src/ui/responder/view_model/responder_auth_view_model.dart';
import 'package:rescue_911/src/ui/responder/view_model/responder_queue_view_model.dart';

const _onDuty = Responder(
  responderId: 'POL-001',
  fullName: 'Insp. Musa Danjuma',
  agency: 'Police',
  onDuty: true,
);

ResponderPing _ping(int id, {PingStatus status = PingStatus.pending}) =>
    ResponderPing(
      id: id,
      publicId: 'pub$id',
      status: status,
      agency: 'Police',
      userPoint: const GeoPoint(latitude: 8.98, longitude: 7.37),
      responderId: status == PingStatus.pending ? null : 'POL-001',
    );

class _FakeService extends ResponderService {
  _FakeService() : super(ApiClient(Dio()));

  Result<List<ResponderPing>> queue = const Ok([]);
  Result<void> acceptResult = const Ok(null);
  final calls = <String>[];

  @override
  Future<Result<Responder?>> status() async => const Ok(_onDuty);

  void Function()? onPings;

  @override
  Future<Result<List<ResponderPing>>> pings() async {
    onPings?.call();
    return queue;
  }

  @override
  Future<Result<void>> accept(int pingId) async {
    calls.add('accept $pingId');
    return acceptResult;
  }

  @override
  Future<Result<void>> setStatus(int pingId, String status) async {
    calls.add('$status $pingId');
    return const Ok(null);
  }

  @override
  Future<Result<void>> setMode(int pingId, String mode) async {
    calls.add('mode $pingId $mode');
    return const Ok(null);
  }
}

Future<(ProviderContainer, List<int>)> _queue(_FakeService service) async {
  final alerts = <int>[];
  final container = ProviderContainer(
    overrides: [
      responderServiceProvider.overrideWithValue(service),
      newPingAlertProvider.overrideWithValue(() => alerts.add(1)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(responderAuthViewModelProvider.future);
  container.read(responderQueueViewModelProvider);
  await pumpEventQueue();
  return (container, alerts);
}

void main() {
  test('parses a queued ping', () {
    final ping = ResponderPing.fromJson(
      JsonReader({
        'id': 238,
        'public_id': 'kZ8',
        'status': 'en_route',
        'agency': 'Police',
        'user_lat': 8.98487,
        'user_lng': 7.369,
        'user_accuracy': 40,
        'user_address': '3rd Avenue Fha Lugbe',
        'medical_profile': 'Blood group: O+',
        'has_voice': true,
        'voice_seconds': 12,
        'responder_id': 'POL-001',
        'responder_mode': 'biking',
        'created_at': '2026-11-19T10:12:00Z',
      }),
    );
    expect(ping.status, PingStatus.enRoute);
    expect(ping.isClaimed, isTrue);
    expect(ping.isActive, isTrue);
    expect(ping.hasVoice, isTrue);
    expect(ping.createdAt, isNotNull);
  });

  test('the voice note URL carries its token', () {
    expect(
      ResponderService.voiceUrl('https://api.test', 'a b'),
      'https://api.test/api/ping/a%20b/voice?token=a%20b',
    );
  });

  test('on duty, pings load and a new one alerts once', () async {
    final service = _FakeService()..queue = Ok([_ping(1)]);
    final (container, alerts) = await _queue(service);
    expect(container.read(responderQueueViewModelProvider).waiting, 1);
    expect(alerts, hasLength(1));

    await container.read(responderQueueViewModelProvider.notifier).refresh();
    expect(alerts, hasLength(1));

    service.queue = Ok([_ping(1), _ping(2)]);
    await container.read(responderQueueViewModelProvider.notifier).refresh();
    expect(alerts, hasLength(2));
  });

  test('losing the Accept race says so and refreshes', () async {
    final service = _FakeService()
      ..queue = Ok([_ping(7)])
      ..acceptResult = const Err(ConflictFailure());
    final (container, _) = await _queue(service);
    service.queue = const Ok([]);
    await container
        .read(responderQueueViewModelProvider.notifier)
        .accept(_ping(7));
    final state = container.read(responderQueueViewModelProvider);
    expect(state.message, 'Another responder accepted this ping first.');
    expect(state.pings, isEmpty);
  });

  test('Accept stays busy until the refreshed queue is in', () async {
    final service = _FakeService()..queue = Ok([_ping(5)]);
    final (container, _) = await _queue(service);
    int? busyDuringRefresh;
    service.onPings = () => busyDuringRefresh = container
        .read(responderQueueViewModelProvider)
        .busyPingId;
    service.queue = Ok([_ping(5, status: PingStatus.accepted)]);
    await container
        .read(responderQueueViewModelProvider.notifier)
        .accept(_ping(5));
    expect(busyDuringRefresh, 5);
    final state = container.read(responderQueueViewModelProvider);
    expect(state.busyPingId, isNull);
    expect(state.pings.single.isClaimed, isTrue);
  });

  test('status and mode go to the server', () async {
    final service = _FakeService()
      ..queue = Ok([_ping(9, status: PingStatus.accepted)]);
    final (container, _) = await _queue(service);
    final actions = container.read(responderQueueViewModelProvider.notifier);
    final ping = _ping(9, status: PingStatus.accepted);
    await actions.setMode(ping, 'biking');
    await actions.setStatus(ping, 'en_route');
    expect(service.calls, ['mode 9 biking', 'en_route 9']);
    expect(
      container.read(responderQueueViewModelProvider).modeFor(ping),
      'biking',
    );
  });

  test('another device signing in signs out from the queue', () async {
    final service = _FakeService()
      ..queue = const Err(UnauthorizedFailure(code: 'session_superseded'));
    final (container, _) = await _queue(service);
    expect(container.read(responderAuthViewModelProvider).value, isNull);
    expect(container.read(responderQueueViewModelProvider).pings, isEmpty);
  });
}
