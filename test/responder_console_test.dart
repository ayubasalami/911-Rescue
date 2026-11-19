import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/core/app_failure.dart';
import 'package:rescue_911/src/core/result.dart';
import 'package:rescue_911/src/data/models/geo_point.dart';
import 'package:rescue_911/src/data/models/responder.dart';
import 'package:rescue_911/src/data/network/api_client.dart';
import 'package:rescue_911/src/data/repositories/location_repository.dart';
import 'package:rescue_911/src/data/services/location_service.dart';
import 'package:rescue_911/src/data/services/responder_service.dart';
import 'package:rescue_911/src/ui/responder/view_model/responder_auth_view_model.dart';
import 'package:rescue_911/src/ui/responder/view_model/responder_console_view_model.dart';
import 'package:rescue_911/src/utils/location_share_gate.dart';
import 'package:rescue_911/src/utils/relative_time.dart';

const _home = GeoPoint(latitude: 8.98487, longitude: 7.369);

Responder _musa({bool onDuty = false}) => Responder(
  responderId: 'POL-001',
  fullName: 'Insp. Musa Danjuma',
  agency: 'Police',
  onDuty: onDuty,
);

class _FakeService extends ResponderService {
  _FakeService({required this.current}) : super(ApiClient(Dio()));

  Responder current;
  Result<bool>? dutyResult;
  Result<void> locationResult = const Ok(null);
  final sent = <GeoPoint>[];

  @override
  Future<Result<Responder?>> status() async => Ok(current);

  @override
  Future<Result<bool>> setDuty(bool onDuty) async => dutyResult ?? Ok(onDuty);

  @override
  Future<Result<void>> sendLocation(GeoPoint point, double accuracy) async {
    sent.add(point);
    return locationResult;
  }
}

class _FakeLocation extends LocationRepository {
  _FakeLocation() : super(LocationService());

  final fixes = StreamController<TrackedPosition>.broadcast();
  LocationResult first = const LocationResult.granted(_home, accuracy: 20);

  @override
  Future<LocationResult> currentPosition() async => first;

  @override
  Stream<TrackedPosition> positionStream() => fixes.stream;
}

Future<ProviderContainer> _console(
  _FakeService service,
  _FakeLocation location,
) async {
  final container = ProviderContainer(
    overrides: [
      responderServiceProvider.overrideWithValue(service),
      locationRepositoryProvider.overrideWithValue(location),
    ],
  );
  addTearDown(container.dispose);
  await container.read(responderAuthViewModelProvider.future);
  container.read(responderConsoleViewModelProvider);
  await pumpEventQueue();
  return container;
}

void main() {
  group('sharing rules', () {
    test('a fix worse than 150 m is held back', () {
      expect(
        decideShare(point: _home, accuracyMeters: 200),
        ShareDecision.weak,
      );
    });

    test('the first fix and a 25 m move are sent; small moves wait', () {
      expect(decideShare(point: _home, accuracyMeters: 20), ShareDecision.send);
      const near = GeoPoint(latitude: 8.98497, longitude: 7.369); // ~11 m
      const far = GeoPoint(latitude: 8.98537, longitude: 7.369); // ~55 m
      expect(
        decideShare(point: near, accuracyMeters: 20, lastSent: _home),
        ShareDecision.hold,
      );
      expect(
        decideShare(point: far, accuracyMeters: 20, lastSent: _home),
        ShareDecision.send,
      );
    });
  });

  test('relative times read like the web', () {
    final now = DateTime(2026, 11, 19, 10);
    expect(relativeTime(now, now: now), 'just now');
    expect(
      relativeTime(now.subtract(const Duration(minutes: 5)), now: now),
      '5 min ago',
    );
    expect(
      relativeTime(now.subtract(const Duration(hours: 3)), now: now),
      '3h ago',
    );
    expect(
      relativeTime(now.subtract(const Duration(days: 15)), now: now),
      '15d ago',
    );
  });

  test('going on duty starts sharing; off duty stops it', () async {
    final service = _FakeService(current: _musa());
    final location = _FakeLocation();
    final container = await _console(service, location);
    expect(service.sent, isEmpty);

    await container
        .read(responderConsoleViewModelProvider.notifier)
        .toggleDuty();
    await pumpEventQueue();
    expect(
      container.read(responderAuthViewModelProvider).value!.onDuty,
      isTrue,
    );
    expect(service.sent, [_home]);
    expect(
      container.read(responderConsoleViewModelProvider).position,
      isNotNull,
    );

    await container
        .read(responderConsoleViewModelProvider.notifier)
        .toggleDuty();
    await pumpEventQueue();
    expect(container.read(responderConsoleViewModelProvider).position, isNull);
    location.fixes.add(
      const TrackedPosition(
        point: GeoPoint(latitude: 9, longitude: 7.4),
        accuracyMeters: 10,
      ),
    );
    await pumpEventQueue();
    expect(service.sent, hasLength(1));
  });

  test('a weak fix keeps the last good position and says why', () async {
    final service = _FakeService(current: _musa(onDuty: true));
    final location = _FakeLocation();
    final container = await _console(service, location);
    location.fixes.add(
      const TrackedPosition(
        point: GeoPoint(latitude: 9.1, longitude: 7.5),
        accuracyMeters: 400,
      ),
    );
    await pumpEventQueue();
    final state = container.read(responderConsoleViewModelProvider);
    expect(state.position!.point, _home);
    expect(state.locationMessage, contains('Weak GPS signal (±400m)'));
    expect(service.sent, [_home]);
  });

  test('denied location says dispatch cannot see them', () async {
    final location = _FakeLocation()
      ..first = const LocationResult.unavailable(LocationAccessStatus.denied);
    final container = await _console(
      _FakeService(current: _musa(onDuty: true)),
      location,
    );
    expect(
      container.read(responderConsoleViewModelProvider).locationMessage,
      contains('Dispatch cannot see where you are'),
    );
  });

  test('another device signing in stops sharing and signs out', () async {
    final service = _FakeService(current: _musa(onDuty: true))
      ..locationResult = const Err(
        UnauthorizedFailure(code: 'session_superseded'),
      );
    final container = await _console(service, _FakeLocation());
    expect(container.read(responderAuthViewModelProvider).value, isNull);
    expect(container.read(responderSignOutNoticeProvider), isNotNull);
    expect(container.read(responderConsoleViewModelProvider).position, isNull);
  });

  test('a failed duty change shows why and keeps the duty', () async {
    final service = _FakeService(current: _musa())
      ..dutyResult = const Err(NetworkFailure());
    final container = await _console(service, _FakeLocation());
    await container
        .read(responderConsoleViewModelProvider.notifier)
        .toggleDuty();
    expect(
      container.read(responderAuthViewModelProvider).value!.onDuty,
      isFalse,
    );
    expect(
      container.read(responderConsoleViewModelProvider).dutyError,
      isNotNull,
    );
  });
}
