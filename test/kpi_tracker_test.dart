import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/data/services/kpi_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records each `/api/events` body and answers with [status], or fails the
/// request outright when [status] is null.
class _Server implements HttpClientAdapter {
  int? status = 202;
  final bodies = <Map<String, dynamic>>[];
  final clients = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    bodies.add(Map<String, dynamic>.from(options.data as Map));
    clients.add(options.headers['X-Client'] as String?);
    final status = this.status;
    if (status == null) throw const SocketExceptionStub();
    return ResponseBody.fromString('{"ok":true}', status);
  }

  @override
  void close({bool force = false}) {}
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}

void main() {
  late _Server server;
  late DateTime now;
  var ids = 0;

  Future<KpiTracker> tracker() async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = server;
    return KpiTracker(
      dio: dio,
      prefs: await SharedPreferences.getInstance(),
      platform: 'android',
      appVersion: '1.0.0-staging',
      now: () => now,
      newId: () => 'id${ids++}',
    )..load();
  }

  List<String> names(List<Map<String, Object?>> events) => [
    for (final e in events) e['name']! as String,
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _Server();
    now = DateTime(2026, 11, 19, 9);
    ids = 0;
  });

  test('the first event starts a visit', () async {
    final kpi = await tracker();
    kpi.track('map_load');
    expect(names(kpi.queued), ['session_start', 'map_load']);
  });

  test('a short gap keeps the visit; 30 minutes starts a new one', () async {
    final kpi = await tracker();
    kpi.track('map_load');
    final first = kpi.sessionId;

    now = now.add(const Duration(minutes: 29));
    kpi.track('app_open');
    expect(kpi.sessionId, first);

    now = now.add(const Duration(minutes: 30));
    kpi.track('app_open');
    expect(kpi.sessionId, isNot(first));
    expect(names(kpi.queued).where((n) => n == 'session_start'), hasLength(2));
  });

  test('a relaunch within 30 minutes continues the visit', () async {
    final first = await tracker();
    first.track('map_load');
    now = now.add(const Duration(minutes: 5));
    final relaunched = await tracker();
    relaunched.track('app_open');
    expect(relaunched.sessionId, first.sessionId);
    expect(relaunched.anonId, first.anonId);
  });

  test('sends the batch with the spec fields and empties the queue', () async {
    final kpi = await tracker()
      ..signedIn = true;
    kpi.track('search_query', {'query_length': 7});
    await kpi.flush();

    final body = server.bodies.single;
    expect(body['platform'], 'android');
    expect(body['app_version'], '1.0.0-staging');
    expect(body['signed_in'], isTrue);
    expect(body['anon_id'], kpi.anonId);
    final events = (body['events'] as List).cast<Map>();
    expect(events.last['props'], {'query_length': 7});
    expect(server.clients.single, 'android');
    expect(kpi.queued, isEmpty);
  });

  test('25 queued events flush without waiting for the timer', () async {
    final kpi = await tracker();
    for (var i = 0; i < 24; i++) {
      kpi.track('heartbeat');
    }
    await pumpEventQueue();
    expect(server.bodies, hasLength(1));
  });

  test('offline keeps the events; three failures drop them', () async {
    final kpi = await tracker();
    kpi.track('map_load');
    server.status = null;
    await kpi.flush();
    await kpi.flush();
    expect(kpi.queued, hasLength(2));
    await kpi.flush();
    expect(kpi.queued, isEmpty);
  });

  test('a server error is retried at the next flush', () async {
    final kpi = await tracker();
    kpi.track('map_load');
    server.status = 503;
    await kpi.flush();
    expect(kpi.queued, hasLength(2));
    server.status = 202;
    await kpi.flush();
    expect(kpi.queued, isEmpty);
  });

  test('a rejected batch is dropped, not retried', () async {
    final kpi = await tracker();
    kpi.track('map_load');
    server.status = 400;
    await kpi.flush();
    expect(kpi.queued, isEmpty);
  });

  test('events older than 72 hours are not sent', () async {
    final kpi = await tracker();
    kpi.track('map_load');
    now = now.add(const Duration(hours: 73));
    await kpi.flush();
    expect(server.bodies, isEmpty);
    expect(kpi.queued, isEmpty);
  });

  test('the queue survives a restart, capped at 500', () async {
    final kpi = await tracker();
    server.status = null;
    for (var i = 0; i < 520; i++) {
      kpi.track('heartbeat');
    }
    final relaunched = await tracker();
    expect(relaunched.queued, hasLength(KpiTracker.maxQueue));
    final saved = jsonDecode(
      (await SharedPreferences.getInstance()).getString('kpi_queue')!,
    );
    expect(saved, hasLength(KpiTracker.maxQueue));
  });

  test('invalid names are dropped', () async {
    final kpi = await tracker();
    kpi.track('Bad Name');
    expect(kpi.queued, isEmpty);
  });

  test('deleting the account gives a new install id', () async {
    final kpi = await tracker();
    final before = kpi.anonId;
    await kpi.resetIdentity();
    expect(kpi.anonId, isNot(before));
  });
}
