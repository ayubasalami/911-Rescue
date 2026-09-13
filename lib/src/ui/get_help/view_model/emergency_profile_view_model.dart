import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/emergency_profile.dart';
import '../../../data/repositories/emergency_profile_repository.dart';

class EmergencyProfileViewModel extends AsyncNotifier<EmergencyProfile> {
  @override
  Future<EmergencyProfile> build() => ref.read(emergencyProfileRepositoryProvider).load();

  Future<void> save(EmergencyProfile profile) async {
    await ref.read(emergencyProfileRepositoryProvider).save(profile);
    state = AsyncData(profile);
  }

  Future<void> clear() async {
    await ref.read(emergencyProfileRepositoryProvider).clear();
    state = const AsyncData(EmergencyProfile.empty);
  }
}

final emergencyProfileViewModelProvider =
    AsyncNotifierProvider<EmergencyProfileViewModel, EmergencyProfile>(EmergencyProfileViewModel.new);
