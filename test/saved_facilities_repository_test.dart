import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/core/result.dart';
import 'package:rescue_911/src/data/models/saved_facility.dart';
import 'package:rescue_911/src/data/network/api_client.dart';
import 'package:rescue_911/src/data/repositories/saved_facilities_repository.dart';
import 'package:rescue_911/src/data/services/saved_facilities_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An in-memory account: what's saved on "the server".
class _FakeService extends SavedFacilitiesService {
  _FakeService([Iterable<String> server = const []])
    : server = {...server},
      super(ApiClient(Dio()));

  final Set<String> server;
  final saves = <String>[];
  final unsaves = <String>[];

  @override
  Future<Result<void>> save(SavedFacility facility) async {
    saves.add(facility.name);
    server.add(facility.name);
    return const Ok(null);
  }

  @override
  Future<Result<void>> unsave(String name) async {
    unsaves.add(name);
    server.remove(name);
    return const Ok(null);
  }

  @override
  Future<Result<List<SavedFacility>>> fetchSaved() async =>
      Ok([for (final name in server) SavedFacility(name: name, synced: true)]);
}

List<String> _names(List<SavedFacility> items) =>
    [for (final item in items) item.name]..sort();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves on the phone without signing in', () async {
    final service = _FakeService();
    final repository = SavedFacilitiesRepository(service);
    await repository.save(const SavedFacility(name: 'LASUTH'), signedIn: false);
    expect(_names(await repository.load()), ['LASUTH']);
    expect(service.saves, isEmpty);
  });

  test('first sync replays local saves, then takes the server list', () async {
    final service = _FakeService(['Saved on web']);
    final repository = SavedFacilitiesRepository(service);
    await repository.save(const SavedFacility(name: 'LASUTH'), signedIn: false);
    final synced = await repository.sync('a@b.com');
    expect(service.saves, ['LASUTH']);
    expect(_names(synced), ['LASUTH', 'Saved on web']);
  });

  test('after the first sync the server decides', () async {
    final service = _FakeService();
    final repository = SavedFacilitiesRepository(service);
    await repository.save(const SavedFacility(name: 'LASUTH'), signedIn: true);
    await repository.sync('a@b.com');

    service.server.remove('LASUTH'); // Unsaved on the web.
    expect(_names(await repository.sync('a@b.com')), isEmpty);
  });

  test('an unsave while signed out reaches the account at sync', () async {
    final service = _FakeService();
    final repository = SavedFacilitiesRepository(service);
    await repository.save(const SavedFacility(name: 'LASUTH'), signedIn: true);
    await repository.sync('a@b.com');

    await repository.unsave('LASUTH', signedIn: false);
    expect(service.unsaves, isEmpty);
    expect(_names(await repository.sync('a@b.com')), isEmpty);
    expect(service.unsaves, ['LASUTH']);
  });

  test('after deleting the account the phone keeps its saves', () async {
    final service = _FakeService();
    final repository = SavedFacilitiesRepository(service);
    await repository.save(const SavedFacility(name: 'LASUTH'), signedIn: true);
    await repository.sync('a@b.com');

    final kept = await repository.forgetAccount();
    expect(_names(kept), ['LASUTH']);
    expect(kept.single.synced, isFalse);

    // Signing in again replays it, as for any first sync.
    service.server.clear();
    service.saves.clear();
    await repository.sync('a@b.com');
    expect(service.saves, ['LASUTH']);
  });
}
