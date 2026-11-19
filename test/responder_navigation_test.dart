import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rescue_911/src/core/result.dart';
import 'package:rescue_911/src/core/theme/app_theme.dart';
import 'package:rescue_911/src/data/models/geo_point.dart';
import 'package:rescue_911/src/data/models/ping.dart';
import 'package:rescue_911/src/data/models/responder.dart';
import 'package:rescue_911/src/data/network/api_client.dart';
import 'package:rescue_911/src/data/repositories/location_repository.dart';
import 'package:rescue_911/src/data/services/location_service.dart';
import 'package:rescue_911/src/data/services/responder_service.dart';
import 'package:rescue_911/src/ui/responder/screens/responder_navigation_screen.dart';
import 'package:rescue_911/src/ui/responder/view_model/responder_queue_view_model.dart';

const _onDuty = Responder(
  responderId: 'POL-001',
  fullName: 'Insp. Musa Danjuma',
  agency: 'Police',
  onDuty: true,
);

class _FakeService extends ResponderService {
  _FakeService(this.status_) : super(ApiClient(Dio()));

  PingStatus status_;

  @override
  Future<Result<Responder?>> status() async => const Ok(_onDuty);

  @override
  Future<Result<List<ResponderPing>>> pings() async => Ok([
    ResponderPing(
      id: 9,
      publicId: 'pub9',
      status: status_,
      agency: 'Police',
      userPoint: const GeoPoint(latitude: 8.98, longitude: 7.37),
      userAccuracy: 40,
      responderId: 'POL-001',
    ),
  ]);

  @override
  Future<Result<void>> sendLocation(GeoPoint point, double accuracy) async =>
      const Ok(null);
}

/// No fix yet, so the screen waits for GPS rather than routing.
class _NoFix extends LocationRepository {
  _NoFix() : super(LocationService());

  @override
  Future<LocationResult> currentPosition() async =>
      const LocationResult.unavailable(LocationAccessStatus.timedOut);

  @override
  Stream<TrackedPosition> positionStream() => const Stream.empty();
}

Future<void> _pump(WidgetTester tester, _FakeService service) async {
  final router = GoRouter(
    initialLocation: '/nav',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('console')),
        routes: [
          GoRoute(
            path: 'nav',
            builder: (_, _) => const ResponderNavigationScreen(pingId: 9),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        responderServiceProvider.overrideWithValue(service),
        locationRepositoryProvider.overrideWithValue(_NoFix()),
        newPingAlertProvider.overrideWithValue(() {}),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('shows the ping, waits for GPS and offers the next step', (
    tester,
  ) async {
    await _pump(tester, _FakeService(PingStatus.accepted));
    expect(find.text('Navigating to ping #9'), findsOneWidget);
    expect(find.text('Waiting for your GPS fix…'), findsOneWidget);
    expect(find.text('On my way'), findsOneWidget);
    expect(find.text('Resolve'), findsOneWidget);
    expect(find.text('🧭 Heading up'), findsOneWidget);
  });

  testWidgets('closes once the ping is no longer active', (tester) async {
    await _pump(tester, _FakeService(PingStatus.resolved));
    await tester.pumpAndSettle();
    expect(find.text('console'), findsOneWidget);
  });
}
