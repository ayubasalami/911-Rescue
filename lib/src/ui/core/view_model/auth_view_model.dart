import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics_events.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/analytics_service.dart';

final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, AppUser?>(
  AuthViewModel.new,
);

/// The signed-in user, or null. Starts from the saved session cookie via
/// `/api/user_status`.
class AuthViewModel extends AsyncNotifier<AppUser?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AppUser?> build() async =>
      (await _repository.currentUser()).valueOrNull;

  /// Returns a message to show the user, or null when there's nothing to
  /// say (signed in, or the picker was closed).
  Future<String?> signIn() async {
    switch (await _repository.signIn()) {
      case SignedIn(:final user):
        state = AsyncData(user);
        _log(AnalyticsEvents.login, {'method': 'google'});
        return null;
      case SignInCancelled():
        return null;
      case SignInFailed(:final message):
        return message;
    }
  }

  Future<void> signOut() async {
    state = const AsyncData(null);
    _log(AnalyticsEvents.logout);
    await _repository.signOut();
  }

  void _log(String name, [Map<String, Object>? parameters]) =>
      ref.read(analyticsServiceProvider).logEvent(name, parameters: parameters);
}
