import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ping.dart';
import '../../../data/models/responder.dart';
import '../../../data/services/responder_service.dart';
import '../../../utils/relative_time.dart';
import '../view_model/responder_queue_view_model.dart';

/// The web console's travel modes, in its order.
const responderModes = [
  ('driving', 'Car', '🚗'),
  ('biking', 'Motorcycle', '🏍️'),
  ('cycling', 'Bicycle', '🚲'),
  ('walking', 'Walking', '🚶'),
];

String _statusLabel(PingStatus status) => switch (status) {
  PingStatus.enRoute => 'en route',
  _ => status.name,
};

/// One ping in the queue, as the web console shows it: what the citizen
/// sent, then Accept, or — once it's theirs — how they're travelling and
/// the next step.
class ResponderPingCard extends ConsumerWidget {
  const ResponderPingCard({
    super.key,
    required this.ping,
    this.onOpenNavigation,
  });

  final ResponderPing ping;

  /// Null until the navigation map exists.
  final VoidCallback? onOpenNavigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final queue = ref.watch(responderQueueViewModelProvider);
    final actions = ref.read(responderQueueViewModelProvider.notifier);
    final busy = queue.busyPingId == ping.id;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ping.isPending ? palette.danger.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ping.isPending ? '🚨 New ping' : '#${ping.id}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                _statusLabel(ping.status),
                style: TextStyle(
                  color: palette.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          ResponderPingDetails(ping: ping),
          if (ping.isClaimed && ping.isActive) ...[
            const SizedBox(height: 10),
            Text(
              'HOW ARE YOU TRAVELLING?',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              spacing: 6,
              children: [
                for (final (key, label, icon) in responderModes)
                  Expanded(
                    child: _ModeTile(
                      label: label,
                      icon: icon,
                      selected: queue.modeFor(ping) == key,
                      onTap: () => actions.setMode(ping, key),
                    ),
                  ),
              ],
            ),
            if (onOpenNavigation != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onOpenNavigation,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text(
                    '🧭 Open navigation map',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (!ping.isClaimed)
                _ActionButton(
                  label: busy ? '…' : 'Accept',
                  color: palette.accentGreen,
                  onTap: busy ? null : () => actions.accept(ping),
                ),
              if (ping.isClaimed && ping.status == PingStatus.accepted)
                _ActionButton(
                  label: 'On my way',
                  color: palette.primary,
                  onTap: busy
                      ? null
                      : () => actions.setStatus(ping, 'en_route'),
                ),
              if (ping.isClaimed && ping.status == PingStatus.enRoute)
                _ActionButton(
                  label: 'Arrived',
                  color: palette.primary,
                  onTap: busy ? null : () => actions.setStatus(ping, 'arrived'),
                ),
              if (ping.isClaimed && ping.isActive)
                _ActionButton(
                  label: 'Resolve',
                  color: palette.textSecondary,
                  onTap: busy
                      ? null
                      : () => actions.setStatus(ping, 'resolved'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the citizen sent: medical profile, address, voice note, position,
/// when, and their note. Shared by the queue card and the navigation map,
/// where a voice note can arrive mid-journey.
class ResponderPingDetails extends StatelessWidget {
  const ResponderPingDetails({super.key, required this.ping});

  final ResponderPing ping;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final muted = TextStyle(color: palette.textSecondary, fontSize: 12);
    final accuracy = ping.userAccuracy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ping.medicalProfile case final profile?
            when profile.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: palette.danger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: palette.danger),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🩺 MEDICAL PROFILE',
                  style: TextStyle(
                    color: palette.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(profile, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
        ],
        if (ping.address case final address? when address.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '📍 $address',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
        if (ping.hasVoice) ...[
          const SizedBox(height: 6),
          _VoiceNote(ping: ping),
        ],
        const SizedBox(height: 4),
        Text(
          '${ping.userPoint.latitude.toStringAsFixed(5)}, '
          '${ping.userPoint.longitude.toStringAsFixed(5)}'
          '${accuracy == null ? '' : ' (±${accuracy.round()}m)'}',
          style: muted,
        ),
        if (ping.createdAt case final created?)
          Text('Raised ${relativeTime(created)}', style: muted),
        if (ping.note case final note? when note.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '“$note”',
            style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? palette.inputBg : null,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected ? palette.primary : palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

/// The citizen's voice note, streamed from the server, in the web's audio
/// bar: play/pause, elapsed time, a seek bar and the length, captioned
/// "🎤 Voice description". Nothing is fetched until it's played.
class _VoiceNote extends ConsumerStatefulWidget {
  const _VoiceNote({required this.ping});

  final ResponderPing ping;

  @override
  ConsumerState<_VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends ConsumerState<_VoiceNote> {
  AudioPlayer? _player;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _playing = false;
  bool _loading = false;
  bool _failed = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _release() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    unawaited(_player?.dispose());
    _player = null;
  }

  Future<AudioPlayer> _load() async {
    final player = AudioPlayer();
    _player = player;
    _subscriptions
      ..add(
        player.playerStateStream.listen((state) {
          if (!mounted) return;
          final done = state.processingState == ProcessingState.completed;
          if (done) {
            unawaited(player.pause());
            unawaited(player.seek(Duration.zero));
          }
          setState(() => _playing = state.playing && !done);
        }),
      )
      ..add(
        player.positionStream.listen((position) {
          if (mounted) setState(() => _position = position);
        }),
      )
      ..add(
        player.durationStream.listen((duration) {
          if (mounted && duration != null) {
            setState(() => _duration = duration);
          }
        }),
      );
    await player.setUrl(
      ResponderService.voiceUrl(
        ref.read(appConfigProvider).apiBaseUrl,
        widget.ping.publicId,
      ),
    );
    return player;
  }

  Future<void> _toggle() async {
    final current = _player;
    if (current != null && _playing) {
      await current.pause();
      return;
    }
    try {
      var player = current;
      if (player == null) {
        setState(() {
          _loading = true;
          _failed = false;
        });
        player = await _load();
      }
      if (mounted) setState(() => _loading = false);
      unawaited(player.play());
    } catch (_) {
      // Start again on the next tap rather than give up for good.
      _release();
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// Why it didn't play. Recordings are deleted once a ping closes; while
  /// it's open, the likely cause is the format — Chrome records WebM, which
  /// iPhones can't play.
  String get _failureText => widget.ping.isActive || widget.ping.isPending
      ? 'Couldn\'t play this recording on this phone. Tap play to try '
            'again, or read the transcript below.'
      : 'The recording was deleted when the ping closed.';

  static String _clock(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final seconds = widget.ping.voiceSeconds;
    // Until it loads, the length the citizen's app reported.
    final total =
        _duration ??
        (seconds == null
            ? Duration.zero
            : Duration(milliseconds: (seconds * 1000).round()));
    final max = total.inMilliseconds.toDouble();
    final value = _position.inMilliseconds.toDouble().clamp(0.0, max);
    const foreground = Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF6B6B6B),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: _toggle,
                        tooltip: _playing ? 'Pause' : 'Play voice description',
                        icon: Icon(
                          _playing ? Icons.pause : Icons.play_arrow,
                          color: foreground,
                        ),
                      ),
              ),
              Text(
                _clock(_position),
                style: const TextStyle(color: foreground, fontSize: 13),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: foreground,
                    inactiveTrackColor: foreground.withValues(alpha: 0.35),
                    thumbColor: foreground,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: max <= 0 ? 0 : value,
                    max: max <= 0 ? 1 : max,
                    onChanged: _player == null || max <= 0
                        ? null
                        : (ms) => unawaited(
                            _player?.seek(Duration(milliseconds: ms.round())),
                          ),
                  ),
                ),
              ),
              Text(
                _clock(total),
                style: const TextStyle(color: foreground, fontSize: 13),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _failed ? _failureText : '🎤 Voice description',
          style: TextStyle(
            color: _failed ? palette.danger : palette.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
