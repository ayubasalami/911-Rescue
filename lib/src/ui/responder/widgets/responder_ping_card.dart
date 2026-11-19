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
    final muted = TextStyle(color: palette.textSecondary, fontSize: 12);
    final accuracy = ping.userAccuracy;
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
              style: const TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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

/// The citizen's voice note, streamed from the server. Recordings are
/// deleted once the ping closes, so playback can fail late.
class _VoiceNote extends ConsumerStatefulWidget {
  const _VoiceNote({required this.ping});

  final ResponderPing ping;

  @override
  ConsumerState<_VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends ConsumerState<_VoiceNote> {
  AudioPlayer? _player;
  bool _playing = false;
  bool _failed = false;

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    var player = _player;
    if (player != null && _playing) {
      await player.pause();
      return;
    }
    try {
      if (player == null) {
        player = _player = AudioPlayer();
        player.playerStateStream.listen((state) {
          if (!mounted) return;
          final done = state.processingState == ProcessingState.completed;
          if (done) unawaited(player!.seek(Duration.zero));
          setState(() => _playing = state.playing && !done);
        });
        await player.setUrl(
          ResponderService.voiceUrl(
            ref.read(appConfigProvider).apiBaseUrl,
            widget.ping.publicId,
          ),
        );
      }
      unawaited(player.play());
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final seconds = widget.ping.voiceSeconds;
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: _failed ? null : _toggle,
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          tooltip: _playing ? 'Pause' : 'Play voice description',
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _failed
                ? 'The recording is no longer available.'
                : '🎤 Voice description'
                      '${seconds == null ? '' : ' · ${seconds.round()}s'}',
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
