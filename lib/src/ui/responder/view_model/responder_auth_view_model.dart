import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../core/result.dart';
import '../../../data/models/responder.dart';
import '../../../data/repositories/role_repository.dart';
import '../../../data/services/responder_service.dart';
import '../../core/view_model/role_view_model.dart';

final responderAuthViewModelProvider =
    AsyncNotifierProvider<ResponderAuthViewModel, Responder?>(
      ResponderAuthViewModel.new,
    );

/// Why the responder was signed out, for the sign-in screen: set when
/// another device signs in to the same account.
final responderSignOutNoticeProvider =
    NotifierProvider<ResponderSignOutNotice, String?>(
      ResponderSignOutNotice.new,
    );

class ResponderSignOutNotice extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String? message) => state = message;
}

/// The signed-in responder, or null. Starts from the saved session cookie
/// via `/api/responder/status`.
class ResponderAuthViewModel extends AsyncNotifier<Responder?> {
  ResponderService get _service => ref.read(responderServiceProvider);

  @override
  Future<Responder?> build() async => (await _service.status()).valueOrNull;

  /// Returns the message to show, or null once signed in. Signing in is
  /// what makes this device a responder's.
  Future<String?> signIn(String responderId, String password) async {
    final result = await _service.login(
      responderId: responderId.trim().toUpperCase(),
      password: password,
    );
    switch (result) {
      case Ok(:final value):
        ref.read(responderSignOutNoticeProvider.notifier).show(null);
        ref.read(roleProvider.notifier).choose(AppRole.responder);
        state = AsyncData(value);
        return null;
      case Err(:final failure):
        return failure.userMessage;
    }
  }

  /// Waits for the server, which also takes them off duty: signed out
  /// only here while still on duty there, dispatch would keep counting on
  /// them. Returns a message to show when it couldn't, null once done.
  Future<String?> signOut() async {
    final result = await _service.logout();
    if (result case Err(:final failure) when failure is! UnauthorizedFailure) {
      // An expired or taken-over session is already signed out there.
      return 'Couldn\'t sign out. Check your connection and try again.';
    }
    state = const AsyncData(null);
    return null;
  }

  /// Another device signed in to this account: only one may be active, so
  /// this one is signed out locally, without retrying.
  void sessionSuperseded() {
    ref
        .read(responderSignOutNoticeProvider.notifier)
        .show(
          'This account was signed in on another device, so this one was '
          'logged out. Only one device can be active at a time.',
        );
    state = const AsyncData(null);
  }

  /// For any responder request: a superseded session signs out here.
  bool handleFailure(AppFailure failure) {
    if (failure case UnauthorizedFailure(code: 'session_superseded')) {
      sessionSuperseded();
      return true;
    }
    if (failure is UnauthorizedFailure) {
      state = const AsyncData(null);
      return true;
    }
    return false;
  }

  void updateResponder(Responder responder) => state = AsyncData(responder);
}
