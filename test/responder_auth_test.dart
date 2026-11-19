import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/core/app_failure.dart';
import 'package:rescue_911/src/core/result.dart';
import 'package:rescue_911/src/data/models/responder.dart';
import 'package:rescue_911/src/data/network/api_client.dart';
import 'package:rescue_911/src/data/network/json_reader.dart';
import 'package:rescue_911/src/data/repositories/role_repository.dart';
import 'package:rescue_911/src/data/services/responder_service.dart';
import 'package:rescue_911/src/ui/core/view_model/role_view_model.dart';
import 'package:rescue_911/src/ui/responder/view_model/responder_auth_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _musa = Responder(
  responderId: 'POL-001',
  fullName: 'Insp. Musa Danjuma',
  agency: 'Police',
  stationName: 'Akoka Police Division',
  phone: '+2348030000003',
);

class _FakeService extends ResponderService {
  _FakeService({this.loginResult = const Ok(_musa), this.current})
    : super(ApiClient(Dio()));

  final Result<Responder> loginResult;
  final Responder? current;
  String? sentId;
  var loggedOut = false;

  @override
  Future<Result<Responder>> login({
    required String responderId,
    required String password,
  }) async {
    sentId = responderId;
    return loginResult;
  }

  Result<void> logoutResult = const Ok(null);

  @override
  Future<Result<void>> logout() async {
    loggedOut = true;
    return logoutResult;
  }

  @override
  Future<Result<Responder?>> status() async => Ok(current);
}

ProviderContainer _container(_FakeService service) {
  final container = ProviderContainer(
    overrides: [responderServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('parses the responder the API returns', () {
    final responder = Responder.fromJson(
      JsonReader({
        'responder_id': 'POL-001',
        'full_name': 'Insp. Musa Danjuma',
        'agency': 'Police',
        'station_name': 'Akoka Police Division',
        'phone': '+2348030000003',
        'on_duty': true,
      }),
    );
    expect(responder.fullName, 'Insp. Musa Danjuma');
    expect(responder.agencyIcon, '🛡️');
    expect(responder.onDuty, isTrue);
  });

  test('starts from the saved session', () async {
    final container = _container(_FakeService(current: _musa));
    expect(
      await container.read(responderAuthViewModelProvider.future),
      isNotNull,
    );
  });

  test('signing in makes this a responder device', () async {
    final service = _FakeService();
    final container = _container(service);
    await container.read(responderAuthViewModelProvider.future);
    final message = await container
        .read(responderAuthViewModelProvider.notifier)
        .signIn(' pol-001 ', 'secret');
    expect(message, isNull);
    expect(service.sentId, 'POL-001');
    expect(container.read(roleProvider), AppRole.responder);
    await pumpEventQueue();
    expect(await RoleRepository().load(), AppRole.responder);
  });

  test('a wrong password shows the server message, role unchanged', () async {
    final container = _container(
      _FakeService(
        loginResult: const Err(
          UnauthorizedFailure(
            serverMessage: 'Incorrect responder ID or password',
          ),
        ),
      ),
    );
    await container.read(responderAuthViewModelProvider.future);
    final message = await container
        .read(responderAuthViewModelProvider.notifier)
        .signIn('POL-001', 'wrong');
    expect(message, 'Incorrect responder ID or password');
    expect(container.read(roleProvider), isNull);
  });

  test('another device signing in signs this one out with a notice', () async {
    final container = _container(_FakeService(current: _musa));
    await container.read(responderAuthViewModelProvider.future);
    final handled = container
        .read(responderAuthViewModelProvider.notifier)
        .handleFailure(const UnauthorizedFailure(code: 'session_superseded'));
    expect(handled, isTrue);
    expect(container.read(responderAuthViewModelProvider).value, isNull);
    expect(
      container.read(responderSignOutNoticeProvider),
      contains('another device'),
    );
  });

  test('signing out waits for the server, then signs out', () async {
    final service = _FakeService(current: _musa);
    final container = _container(service);
    await container.read(responderAuthViewModelProvider.future);
    final message = await container
        .read(responderAuthViewModelProvider.notifier)
        .signOut();
    expect(message, isNull);
    expect(service.loggedOut, isTrue);
    expect(container.read(responderAuthViewModelProvider).value, isNull);
  });

  test('no connection keeps them signed in, with a reason', () async {
    final service = _FakeService(current: _musa)
      ..logoutResult = const Err(NetworkFailure());
    final container = _container(service);
    await container.read(responderAuthViewModelProvider.future);
    final message = await container
        .read(responderAuthViewModelProvider.notifier)
        .signOut();
    expect(message, contains('Couldn\'t sign out'));
    expect(container.read(responderAuthViewModelProvider).value, isNotNull);
  });

  test('an already-ended session still signs out here', () async {
    final service = _FakeService(current: _musa)
      ..logoutResult = const Err(UnauthorizedFailure());
    final container = _container(service);
    await container.read(responderAuthViewModelProvider.future);
    expect(
      await container.read(responderAuthViewModelProvider.notifier).signOut(),
      isNull,
    );
    expect(container.read(responderAuthViewModelProvider).value, isNull);
  });

  test('the role is remembered across launches', () async {
    final repository = RoleRepository();
    expect(await repository.load(), isNull);
    await repository.save(AppRole.citizen);
    expect(await repository.load(), AppRole.citizen);
  });
}
