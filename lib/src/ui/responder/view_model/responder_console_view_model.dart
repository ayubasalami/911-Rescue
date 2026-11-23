import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/env.dart';
import '../../../core/result.dart';
import '../../../data/models/geo_point.dart';
import '../../../data/models/responder.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../data/services/responder_service.dart';
import '../../../utils/location_share_gate.dart';
import 'responder_auth_view_model.dart';
import 'responder_queue_view_model.dart';

class ResponderConsoleState {
  const ResponderConsoleState({
    this.dutyBusy = false,
    this.dutyError,
    this.position,
    this.lastSentAt,
    this.locationMessage,
  });

  /// A duty change is on its way to the server.
  final bool dutyBusy;
  final String? dutyError;

  /// The last good fix (±150 m or better), shown as "Sharing live position".
  final TrackedPosition? position;
  final DateTime? lastSentAt;

  /// Weak signal, denied permission or no location — the web's texts.
  final String? locationMessage;

  ResponderConsoleState copyWith({
    bool? dutyBusy,
    Object? dutyError = _unset,
    Object? position = _unset,
    Object? lastSentAt = _unset,
    Object? locationMessage = _unset,
  }) => ResponderConsoleState(
    dutyBusy: dutyBusy ?? this.dutyBusy,
    dutyError: identical(dutyError, _unset)
        ? this.dutyError
        : dutyError as String?,
    position: identical(position, _unset)
        ? this.position
        : position as TrackedPosition?,
    lastSentAt: identical(lastSentAt, _unset)
        ? this.lastSentAt
        : lastSentAt as DateTime?,
    locationMessage: identical(locationMessage, _unset)
        ? this.locationMessage
        : locationMessage as String?,
  );
}

const _unset = Object();

final responderConsoleViewModelProvider =
    NotifierProvider<ResponderConsoleViewModel, ResponderConsoleState>(
      ResponderConsoleViewModel.new,
    );

/// Duty and location sharing for the console. While on duty the position
/// is sent as the web does — straight away after moving 25 m, and again
/// every 20 seconds — and the screen stays awake, since sharing only runs
/// while the app is open.
class ResponderConsoleViewModel extends Notifier<ResponderConsoleState> {
  static const heartbeat = Duration(seconds: 20);

  StreamSubscription<TrackedPosition>? _fixes;
  Timer? _heartbeat;
  GeoPoint? _lastSent;
  bool _sharing = false;

  ResponderService get _service => ref.read(responderServiceProvider);
  ResponderAuthViewModel get _auth =>
      ref.read(responderAuthViewModelProvider.notifier);

  @override
  ResponderConsoleState build() {
    ref.onDispose(_stopSharing);
    ref.listen(
      responderAuthViewModelProvider,
      (_, next) => _follow(next.value),
      fireImmediately: true,
    );
    return const ResponderConsoleState();
  }

  /// Shares while signed in and on duty, and stops otherwise.
  void _follow(Responder? responder) {
    if (responder?.onDuty ?? false) {
      unawaited(_startSharing());
    } else {
      _stopSharing();
    }
  }

  /// Shown wherever going off duty is refused.
  static const activePingMessage =
      'Resolve your active ping before going off duty.';

  Future<void> toggleDuty() async {
    final responder = ref.read(responderAuthViewModelProvider).value;
    if (responder == null || state.dutyBusy) return;
    // The citizen is waiting on this responder's position and ETA.
    if (responder.onDuty &&
        ref.read(responderQueueViewModelProvider).hasActivePing) {
      state = state.copyWith(dutyError: activePingMessage);
      return;
    }
    state = state.copyWith(dutyBusy: true, dutyError: null);
    final result = await _service.setDuty(!responder.onDuty);
    switch (result) {
      case Ok(:final value):
        state = state.copyWith(dutyBusy: false);
        _auth.updateResponder(responder.copyWith(onDuty: value));
      case Err(:final failure):
        state = state.copyWith(dutyBusy: false);
        if (!_auth.handleFailure(failure)) {
          state = state.copyWith(dutyError: failure.userMessage);
        }
    }
  }

  Future<void> _startSharing() async {
    if (_sharing) return;
    _sharing = true;
    _setWakelock(true);
    // One fix first, both to send straight away and to say why there's
    // none (the live stream just stays quiet when access is refused).
    final first = await ref.read(locationRepositoryProvider).currentPosition();
    if (!_sharing) return;
    if (first.position case final point?) {
      _onFix(
        TrackedPosition(point: point, accuracyMeters: first.accuracy ?? 50),
      );
    } else {
      state = state.copyWith(
        locationMessage: switch (first.status) {
          LocationAccessStatus.denied || LocationAccessStatus.deniedForever =>
            'Location permission denied. Dispatch cannot see where you are.',
          _ => 'Could not get your location.',
        },
      );
    }
    _fixes = ref
        .read(locationRepositoryProvider)
        .positionStream()
        .listen(_onFix);
    _heartbeat = Timer.periodic(heartbeat, (_) {
      final position = state.position;
      if (position != null) unawaited(_send(position));
    });
  }

  void _stopSharing() {
    if (!_sharing) return;
    _sharing = false;
    _fixes?.cancel();
    _fixes = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _lastSent = null;
    _setWakelock(false);
    if (ref.mounted) {
      state = state.copyWith(
        position: null,
        lastSentAt: null,
        locationMessage: null,
      );
    }
  }

  void _onFix(TrackedPosition fix) {
    if (!_sharing) return;
    switch (decideShare(
      point: fix.point,
      accuracyMeters: fix.accuracyMeters,
      lastSent: _lastSent,
    )) {
      case ShareDecision.weak:
        state = state.copyWith(
          locationMessage:
              'Weak GPS signal (±${fix.accuracyMeters.round()}m). Holding '
              'last good position.',
        );
      case ShareDecision.send:
        state = state.copyWith(position: fix, locationMessage: null);
        unawaited(_send(fix));
      case ShareDecision.hold:
        state = state.copyWith(position: fix, locationMessage: null);
    }
  }

  Future<void> _send(TrackedPosition fix) async {
    final result = await _service.sendLocation(fix.point, fix.accuracyMeters);
    if (!_sharing || !ref.mounted) return;
    switch (result) {
      case Ok():
        _lastSent = fix.point;
        state = state.copyWith(lastSentAt: DateTime.now());
      case Err(:final failure):
        // A lost session signs out; anything else waits for the next beat.
        _auth.handleFailure(failure);
    }
  }

  void _setWakelock(bool on) {
    if (isTestEnvironment) return;
    unawaited(
      (on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError(
        (Object _) {},
      ),
    );
  }
}
