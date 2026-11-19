import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/core/result.dart';
import 'package:rescue_911/src/data/models/responder.dart';
import 'package:rescue_911/src/data/network/api_client.dart';
import 'package:rescue_911/src/data/network/json_reader.dart';
import 'package:rescue_911/src/data/services/responder_service.dart';
import 'package:rescue_911/src/ui/responder/view_model/responder_auth_view_model.dart';
import 'package:rescue_911/src/ui/responder/view_model/responder_history_view_model.dart';

final _json = {
  'history': [
    {
      'id': 227,
      'agency': 'Police',
      'status': 'cancelled',
      'user_address': '38 Layi Oyekanmi Street, Lagos',
      'created_at': '2026-11-04T10:00:00Z',
      'accepted_at': '2026-11-04T10:00:35Z',
      'responder_mode': 'walking',
    },
    {
      'id': 222,
      'agency': 'Police',
      'status': 'resolved',
      'created_at': '2026-10-21T10:00:00Z',
      'accepted_at': '2026-10-21T10:00:16Z',
      'user_email': 'a@b.com',
    },
    {
      'id': 221,
      'agency': 'Police',
      'status': 'resolved',
      'created_at': '2026-10-10T10:00:00Z',
      'accepted_at': '2026-10-10T10:00:07Z',
    },
  ],
  'stats': {'total': 80, 'resolved': 33, 'avg_accept_secs': 46.2},
};

class _FakeService extends ResponderService {
  _FakeService() : super(ApiClient(Dio()));

  var loads = 0;

  @override
  Future<Result<Responder?>> status() async => const Ok(
    Responder(responderId: 'POL-001', fullName: 'Musa', agency: 'Police'),
  );

  @override
  Future<Result<ResponderHistory>> history() async {
    loads++;
    return Ok(ResponderHistory.fromJson(JsonReader(_json)));
  }
}

void main() {
  test('parses the history and its totals', () {
    final history = ResponderHistory.fromJson(JsonReader(_json));
    expect(history.total, 80);
    expect(history.resolved, 33);
    expect(history.avgAcceptSeconds, closeTo(46.2, 0.01));
    expect(history.entries.first.address, contains('Layi Oyekanmi'));
    expect(formatAcceptDelay(history.entries.first.acceptDelay!), '35s');
    expect(formatAcceptDelay(const Duration(seconds: 125)), '2m 5s');
  });

  test('loads with the console and again when opened; tiles filter', () async {
    final service = _FakeService();
    final container = ProviderContainer(
      overrides: [responderServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    await container.read(responderAuthViewModelProvider.future);
    container.read(responderHistoryViewModelProvider);
    await pumpEventQueue();
    expect(service.loads, 1);
    expect(
      container.read(responderHistoryViewModelProvider).history,
      isNotNull,
    );

    final history = container.read(responderHistoryViewModelProvider.notifier);
    history.toggle();
    await pumpEventQueue();
    expect(service.loads, 2);

    history.filterBy(HistoryFilter.resolved);
    expect(
      container
          .read(responderHistoryViewModelProvider)
          .visible
          .map((e) => e.id),
      [222, 221],
    );
    history.filterBy(HistoryFilter.fastest);
    expect(
      container
          .read(responderHistoryViewModelProvider)
          .visible
          .map((e) => e.id),
      [221, 222, 227],
    );
  });
}
