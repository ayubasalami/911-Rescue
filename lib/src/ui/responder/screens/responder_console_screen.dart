import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/responder.dart';
import '../../../data/repositories/role_repository.dart';
import '../../../routing/app_router.dart';
import '../../../utils/relative_time.dart';
import '../../core/view_model/role_view_model.dart';
import '../view_model/responder_auth_view_model.dart';
import '../view_model/responder_console_view_model.dart';
import '../widgets/console_parts.dart';

/// The web's "Responder Console", one scrolling card.
class ResponderConsoleScreen extends ConsumerWidget {
  const ResponderConsoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(responderAuthViewModelProvider, (previous, next) {
      if (next is AsyncData<Responder?> && next.value == null) {
        context.go(AppRoute.responderLogin);
      }
    });
    final auth = ref.watch(responderAuthViewModelProvider);
    final console = ref.watch(responderConsoleViewModelProvider);
    final responder = auth.value;
    if (responder == null) {
      // Signed out (handled by the listener) or still checking the session.
      if (auth is AsyncData<Responder?>) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(AppRoute.responderLogin);
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // An existing session (e.g. switching from the citizen side) makes this
    // device a responder's too.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(roleProvider.notifier).choose(AppRole.responder),
    );
    return ConsolePage(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GradientTitle('Responder Console'),
                  Text(
                    responder.responderId,
                    style: TextStyle(color: context.palette.textSecondary),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () =>
                  ref.read(responderAuthViewModelProvider.notifier).signOut(),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.palette.textPrimary,
                side: BorderSide(color: context.palette.border),
                shape: const StadiumBorder(),
              ),
              child: const Text('Sign out'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ProfileCard(responder: responder),
        const SizedBox(height: 16),
        _DutyCard(responder: responder, console: console),
        const SizedBox(height: 16),
        _LocationCard(onDuty: responder.onDuty, console: console),
        const SizedBox(height: 16),
        ConsoleSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Incoming emergency pings',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                responder.onDuty
                    ? 'No active pings. You will see new ones here within a '
                          'few seconds.'
                    : 'Go on duty to receive pings.',
                style: TextStyle(color: context.palette.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => _switchToCitizen(context, ref, responder),
          child: const Text('← Switch to citizen'),
        ),
      ],
    );
  }
}

/// Location sharing stops once the console is gone, so an on-duty
/// responder goes off duty first rather than look available to dispatch.
Future<void> _switchToCitizen(
  BuildContext context,
  WidgetRef ref,
  Responder responder,
) async {
  if (responder.onDuty) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Go off duty?'),
        content: const Text(
          'Switching to the citizen side stops sharing your location, so '
          'you\'ll go off duty and stop receiving emergency pings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Go off duty'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(responderConsoleViewModelProvider.notifier).goOffDuty();
  }
  if (!context.mounted) return;
  ref.read(roleProvider.notifier).choose(AppRole.citizen);
  context.go(AppRoute.home);
}

class _DutyCard extends ConsumerWidget {
  const _DutyCard({required this.responder, required this.console});

  final Responder responder;
  final ResponderConsoleState console;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final onDuty = responder.onDuty;
    return ConsoleSection(
      borderColor: onDuty ? palette.accentGreen : palette.border,
      borderWidth: 2,
      background: onDuty ? palette.accentGreen.withValues(alpha: 0.06) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  onDuty ? '🟢 On duty' : '⚫ Off duty',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton(
                onPressed: console.dutyBusy
                    ? null
                    : ref
                          .read(responderConsoleViewModelProvider.notifier)
                          .toggleDuty,
                style: FilledButton.styleFrom(
                  backgroundColor: onDuty
                      ? palette.textSecondary
                      : palette.accentGreen,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  console.dutyBusy
                      ? '…'
                      : onDuty
                      ? 'Go off duty'
                      : 'Go on duty',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            onDuty
                ? 'You are visible to dispatch and your location is being '
                      'shared.'
                : 'You will not receive emergency pings while off duty, and '
                      'your location is not shared.',
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
          if (console.dutyError != null) ...[
            const SizedBox(height: 6),
            Text(
              console.dutyError!,
              style: TextStyle(color: palette.danger, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.onDuty, required this.console});

  final bool onDuty;
  final ResponderConsoleState console;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final muted = TextStyle(color: palette.textSecondary, fontSize: 13);
    final position = console.position;
    final lastSent = console.lastSentAt;
    return ConsoleSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location sharing',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (!onDuty)
            Text(
              'Inactive. Go on duty to start sharing your position.',
              style: muted,
            )
          else ...[
            if (console.locationMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  console.locationMessage!,
                  style: TextStyle(color: palette.danger, fontSize: 12.5),
                ),
              ),
            if (position == null)
              Text('Acquiring GPS fix…', style: muted)
            else ...[
              Text(
                '● Sharing live position',
                style: TextStyle(
                  color: palette.accentGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${position.point.latitude.toStringAsFixed(5)}, '
                '${position.point.longitude.toStringAsFixed(5)} '
                '(±${position.accuracyMeters.round()}m)',
                style: muted,
              ),
              Text(
                'Last sent to dispatch: '
                '${lastSent == null ? 'never' : relativeTime(lastSent)}',
                style: muted,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.responder});

  final Responder responder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ConsoleSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${responder.agencyIcon} ${responder.fullName}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            responder.agency,
            style: TextStyle(
              color: palette.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (responder.stationName != null) ...[
            const SizedBox(height: 2),
            Text(
              responder.stationName!,
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
          if (responder.phone != null) ...[
            const SizedBox(height: 2),
            Text(
              '📞 ${responder.phone}',
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
