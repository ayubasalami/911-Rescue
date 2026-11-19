import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/role_repository.dart';

/// The saved role, read in `bootstrap` so the first screen is the right
/// one. Null on a fresh install.
final initialRoleProvider = Provider<AppRole?>((ref) => null);

final roleProvider = NotifierProvider<RoleViewModel, AppRole?>(
  RoleViewModel.new,
);

class RoleViewModel extends Notifier<AppRole?> {
  @override
  AppRole? build() => ref.read(initialRoleProvider);

  void choose(AppRole role) {
    if (state == role) return;
    state = role;
    unawaited(ref.read(roleRepositoryProvider).save(role));
  }
}
