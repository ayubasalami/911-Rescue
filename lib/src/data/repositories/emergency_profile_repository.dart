import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergency_profile.dart';

final emergencyProfileRepositoryProvider = Provider<EmergencyProfileRepository>(
  (ref) => EmergencyProfileRepository(),
);

/// Persists [EmergencyProfile] to on-device storage only — matches the web
/// platform's "Stored only on this device," no backend involved.
class EmergencyProfileRepository {
  static const _fullNameKey = 'emergency_profile.full_name';
  static const _bloodGroupKey = 'emergency_profile.blood_group';
  static const _conditionsKey = 'emergency_profile.conditions';
  static const _allergiesKey = 'emergency_profile.allergies';
  static const _nextOfKinKey = 'emergency_profile.next_of_kin';
  static const _nextOfKinPhoneKey = 'emergency_profile.next_of_kin_phone';

  Future<EmergencyProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return EmergencyProfile(
      fullName: prefs.getString(_fullNameKey) ?? '',
      bloodGroup: prefs.getString(_bloodGroupKey) ?? '',
      conditions: prefs.getString(_conditionsKey) ?? '',
      allergies: prefs.getString(_allergiesKey) ?? '',
      nextOfKin: prefs.getString(_nextOfKinKey) ?? '',
      nextOfKinPhone: prefs.getString(_nextOfKinPhoneKey) ?? '',
    );
  }

  Future<void> save(EmergencyProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_fullNameKey, profile.fullName),
      prefs.setString(_bloodGroupKey, profile.bloodGroup),
      prefs.setString(_conditionsKey, profile.conditions),
      prefs.setString(_allergiesKey, profile.allergies),
      prefs.setString(_nextOfKinKey, profile.nextOfKin),
      prefs.setString(_nextOfKinPhoneKey, profile.nextOfKinPhone),
    ]);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_fullNameKey),
      prefs.remove(_bloodGroupKey),
      prefs.remove(_conditionsKey),
      prefs.remove(_allergiesKey),
      prefs.remove(_nextOfKinKey),
      prefs.remove(_nextOfKinPhoneKey),
    ]);
  }
}
