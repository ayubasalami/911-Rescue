import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/role_repository.dart';
import '../../../data/services/analytics_service.dart';

/// The saved role, read in `bootstrap` so the first screen is the right
/// one. Null on a fresh install.
final initialRoleProvider = Provider<AppRole?>((ref) => null);

final roleProvider = NotifierProvider<RoleViewModel, AppRole?>(
  RoleViewModel.new,
);

class RoleViewModel extends Notifier<AppRole?> {
  @override
  AppRole? build() {
    final role = ref.read(initialRoleProvider);
    _pauseAnalyticsFor(role);
    return role;
  }

  void choose(AppRole role) {
    if (state == role) return;
    state = role;
    _pauseAnalyticsFor(role);
    unawaited(ref.read(roleRepositoryProvider).save(role));
  }

  void _pauseAnalyticsFor(AppRole? role) =>
      ref.read(analyticsServiceProvider).setPaused(role == AppRole.responder);
}
