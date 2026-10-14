import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/geo_point.dart';
import '../models/ping.dart';

final activePingRepositoryProvider = Provider<ActivePingRepository>(
  (ref) => ActivePingRepository(),
);

/// The ping the user currently has open — enough to resume tracking it.
/// `public_id` is the only credential for a ping, so without this an app
/// restart mid-emergency would leave the ping running server-side with no
/// way to see its status or cancel it.
class ActivePing {
  const ActivePing({
    required this.publicId,
    required this.agency,
    required this.origin,
    required this.isPinned,
    required this.respondersAvailable,
  });

  final String publicId;
  final PingAgency agency;
  final GeoPoint origin;

  /// A dropped pin rather than the user's live location.
  final bool isPinned;
  final int respondersAvailable;
}

/// Stores the open [ActivePing] on-device. Saved when a ping is raised,
/// cleared when it's cancelled or the server reports it closed.
class ActivePingRepository {
  static const _publicIdKey = 'active_ping.public_id';
  static const _agencyKey = 'active_ping.agency';
  static const _latKey = 'active_ping.lat';
  static const _lngKey = 'active_ping.lng';
  static const _isPinnedKey = 'active_ping.is_pinned';
  static const _respondersKey = 'active_ping.responders_available';

  Future<ActivePing?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final publicId = prefs.getString(_publicIdKey);
    final agency = PingAgencyApi.fromApi(prefs.getString(_agencyKey) ?? '');
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (publicId == null || agency == null || lat == null || lng == null) {
      return null;
    }
    return ActivePing(
      publicId: publicId,
      agency: agency,
      origin: GeoPoint(latitude: lat, longitude: lng),
      isPinned: prefs.getBool(_isPinnedKey) ?? false,
      respondersAvailable: prefs.getInt(_respondersKey) ?? 0,
    );
  }

  Future<void> save(ActivePing ping) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_publicIdKey, ping.publicId),
      prefs.setString(_agencyKey, ping.agency.apiValue),
      prefs.setDouble(_latKey, ping.origin.latitude),
      prefs.setDouble(_lngKey, ping.origin.longitude),
      prefs.setBool(_isPinnedKey, ping.isPinned),
      prefs.setInt(_respondersKey, ping.respondersAvailable),
    ]);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_publicIdKey),
      prefs.remove(_agencyKey),
      prefs.remove(_latKey),
      prefs.remove(_lngKey),
      prefs.remove(_isPinnedKey),
      prefs.remove(_respondersKey),
    ]);
  }
}
