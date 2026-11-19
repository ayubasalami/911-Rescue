import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../core/result.dart';
import '../../../data/models/responder.dart';
import '../../../data/services/responder_service.dart';
import '../../../data/services/voice_directions_service.dart';
import 'responder_auth_view_model.dart';

class ResponderQueueState {
  const ResponderQueueState({
    this.pings = const [],
    this.busyPingId,
    this.message,
    this.modes = const {},
  });

  final List<ResponderPing> pings;

  /// A ping with an action on its way to the server.
  final int? busyPingId;

  /// The last action's problem, e.g. losing an Accept race.
  final String? message;

  /// The travel mode chosen per ping, before the queue catches up.
  final Map<int, String> modes;

  int get waiting => pings.where((ping) => ping.isPending).length;

  /// Car until they say otherwise, as on the web.
  String modeFor(ResponderPing ping) =>
      modes[ping.id] ?? ping.responderMode ?? 'driving';

  ResponderQueueState copyWith({
    List<ResponderPing>? pings,
    Object? busyPingId = _unset,
    Object? message = _unset,
    Map<int, String>? modes,
  }) => ResponderQueueState(
    pings: pings ?? this.pings,
    busyPingId: identical(busyPingId, _unset)
        ? this.busyPingId
        : busyPingId as int?,
    message: identical(message, _unset) ? this.message : message as String?,
    modes: modes ?? this.modes,
  );
}

const _unset = Object();

/// Says a new ping has arrived: a strong vibration and a spoken alert, since
/// there's no push notification to do it.
final newPingAlertProvider = Provider<void Function()>((ref) {
  return () {
    unawaited(HapticFeedback.heavyImpact());
    unawaited(
      ref
          .read(voiceDirectionsServiceProvider)
          .speak('New emergency ping')
          .catchError((Object _) {}),
    );
  };
});

final responderQueueViewModelProvider =
    NotifierProvider<ResponderQueueViewModel, ResponderQueueState>(
      ResponderQueueViewModel.new,
    );

/// The dispatch queue, checked every 8 seconds while on duty as the web
/// does, and the actions on each ping.
class ResponderQueueViewModel extends Notifier<ResponderQueueState> {
  static const pollEvery = Duration(seconds: 8);

  Timer? _timer;
  final _seenPending = <int>{};

  ResponderService get _service => ref.read(responderServiceProvider);
  ResponderAuthViewModel get _auth =>
      ref.read(responderAuthViewModelProvider.notifier);

  @override
  ResponderQueueState build() {
    ref.onDispose(_stop);
    ref.listen(
      responderAuthViewModelProvider,
      (_, next) => _follow(next.value),
      fireImmediately: true,
    );
    return const ResponderQueueState();
  }

  void _follow(Responder? responder) {
    if (responder?.onDuty ?? false) {
      if (_timer != null) return;
      _timer = Timer.periodic(pollEvery, (_) => unawaited(refresh()));
      unawaited(refresh());
    } else {
      _stop();
      _seenPending.clear();
      if (ref.mounted) state = const ResponderQueueState();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    final result = await _service.pings();
    if (!ref.mounted || _timer == null) return;
    switch (result) {
      case Ok(:final value):
        final arrived = value.where(
          (ping) => ping.isPending && !_seenPending.contains(ping.id),
        );
        if (arrived.isNotEmpty) ref.read(newPingAlertProvider)();
        _seenPending
          ..clear()
          ..addAll(value.where((ping) => ping.isPending).map((p) => p.id));
        state = state.copyWith(pings: value);
      case Err(:final failure):
        // A lost session signs out; anything else waits for the next poll.
        _auth.handleFailure(failure);
    }
  }

  Future<void> accept(ResponderPing ping) => _act(
    ping,
    () => _service.accept(ping.id),
    lostRace: 'Another responder accepted this ping first.',
  );

  /// On my way (`en_route`), Arrived (`arrived`) or Resolve (`resolved`).
  Future<void> setStatus(ResponderPing ping, String status) =>
      _act(ping, () => _service.setStatus(ping.id, status));

  Future<void> setMode(ResponderPing ping, String mode) async {
    state = state.copyWith(modes: {...state.modes, ping.id: mode});
    final result = await _service.setMode(ping.id, mode);
    if (result case Err(:final failure) when !_auth.handleFailure(failure)) {
      state = state.copyWith(message: failure.userMessage);
    }
  }

  Future<void> _act(
    ResponderPing ping,
    Future<Result<void>> Function() action, {
    String? lostRace,
  }) async {
    if (state.busyPingId != null) return;
    state = state.copyWith(busyPingId: ping.id, message: null);
    final result = await action();
    if (!ref.mounted) return;
    if (result case Err(:final failure)) {
      if (_auth.handleFailure(failure)) {
        state = state.copyWith(busyPingId: null);
        return;
      }
      state = state.copyWith(
        message: failure is ConflictFailure && lostRace != null
            ? lostRace
            : failure.userMessage,
      );
    }
    // Busy until the queue shows the change: cleared before, the card would
    // flash its old buttons (Accept again) while the refresh is on its way.
    await refresh();
    if (ref.mounted) state = state.copyWith(busyPingId: null);
  }
}
