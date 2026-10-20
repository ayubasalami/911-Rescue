import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics_events.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/result.dart';
import '../../../data/services/analytics_service.dart';
import 'saved_facilities_view_model.dart';

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
  Future<String?> signIn() async =>
      _finishSignIn(await _repository.signIn(), method: 'google');

  /// Sign in with Apple (iOS) — same outcome handling as [signIn].
  Future<String?> signInWithApple() async =>
      _finishSignIn(await _repository.signInWithApple(), method: 'apple');

  String? _finishSignIn(SignInOutcome outcome, {required String method}) {
    switch (outcome) {
      case SignedIn(:final user):
        state = AsyncData(user);
        _log(AnalyticsEvents.login, {'method': method});
        return null;
      case SignInCancelled():
        return null;
      case SignInFailed(:final message, :final reason):
        _log(AnalyticsEvents.loginFailed, {'reason': reason});
        return message;
    }
  }

  /// Deletes the account. Returns a message to show on failure, null once
  /// it's gone — signed out, with the phone's saves kept as its own.
  Future<String?> deleteAccount() async {
    switch (await _repository.deleteAccount()) {
      case Ok():
        state = const AsyncData(null);
        _log(AnalyticsEvents.accountDeleted);
        await ref
            .read(savedFacilitiesViewModelProvider.notifier)
            .forgetAccount();
        return null;
      case Err(:final failure):
        return failure.userMessage;
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
