import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/ping.dart';
import '../../../data/models/responder.dart';
import '../../../data/repositories/role_repository.dart';
import '../../../routing/app_router.dart';
import '../../../utils/relative_time.dart';
import '../../core/view_model/role_view_model.dart';
import '../view_model/responder_auth_view_model.dart';
import '../view_model/responder_console_view_model.dart';
import '../view_model/responder_history_view_model.dart';
import '../view_model/responder_queue_view_model.dart';
import '../widgets/console_parts.dart';
import '../widgets/responder_ping_card.dart';

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
    // An accepted, unresolved ping keeps the responder on duty: no going
    // off duty or signing out until it's done.
    final activePing = ref.watch(
      responderQueueViewModelProvider.select((q) => q.hasActivePing),
    );
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
    // Switching back to citizen is only offered on the sign-in screen, so
    // a responder signs out first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ref.read(roleProvider.notifier).choose(AppRole.responder);
      }
    });
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
            _SignOutButton(enabled: !activePing),
          ],
        ),
        const SizedBox(height: 16),
        _ProfileCard(responder: responder),
        const SizedBox(height: 16),
        _DutyCard(responder: responder, console: console),
        const SizedBox(height: 16),
        _LocationCard(onDuty: responder.onDuty, console: console),
        const SizedBox(height: 16),
        _PingsSection(onDuty: responder.onDuty),
        const SizedBox(height: 16),
        const _HistorySection(),
      ],
    );
  }
}

/// Signs out once the server confirms (which also ends duty there),
/// showing progress meanwhile and staying put if it fails.
class _SignOutButton extends ConsumerStatefulWidget {
  const _SignOutButton({required this.enabled});

  final bool enabled;

  @override
  ConsumerState<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends ConsumerState<_SignOutButton> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _signingOut = true);
    final message = await ref
        .read(responderAuthViewModelProvider.notifier)
        .signOut();
    if (!mounted) return;
    setState(() => _signingOut = false);
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return OutlinedButton(
      onPressed: widget.enabled && !_signingOut ? _signOut : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(color: palette.border),
        shape: const StadiumBorder(),
      ),
      child: _signingOut
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Signing out…'),
              ],
            )
          : const Text('Sign out'),
    );
  }
}

/// The dispatch queue: red while anything is waiting.
class _PingsSection extends ConsumerWidget {
  const _PingsSection({required this.onDuty});

  final bool onDuty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final queue = ref.watch(responderQueueViewModelProvider);
    final waiting = onDuty ? queue.waiting : 0;
    return ConsoleSection(
      borderColor: waiting > 0 ? palette.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Incoming emergency pings'),
                if (waiting > 0)
                  TextSpan(
                    text: '  ($waiting waiting)',
                    style: TextStyle(color: palette.danger),
                  ),
              ],
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (onDuty && queue.message != null) ...[
            const SizedBox(height: 6),
            Text(
              queue.message!,
              style: TextStyle(color: palette.danger, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 8),
          if (!onDuty)
            Text(
              'Go on duty to receive pings.',
              style: TextStyle(color: palette.textSecondary),
            )
          else if (queue.pings.isEmpty)
            Text(
              'No active pings. You will see new ones here within a few '
              'seconds.',
              style: TextStyle(color: palette.textSecondary),
            )
          else
            for (final ping in queue.pings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ResponderPingCard(
                  ping: ping,
                  onOpenNavigation: () =>
                      context.push(AppRoute.responderNavigation(ping.id)),
                ),
              ),
        ],
      ),
    );
  }
}

/// "My ping history": totals that double as filters, then each ping with a
/// coloured edge by how it ended.
class _HistorySection extends ConsumerWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(responderHistoryViewModelProvider);
    final actions = ref.read(responderHistoryViewModelProvider.notifier);
    final history = state.history;
    final visible = state.visible;
    final muted = TextStyle(color: palette.textSecondary, fontSize: 12);
    return ConsoleSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: actions.toggle,
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'My ping history',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (history != null)
                          TextSpan(
                            text: ' · ${history.total} total',
                            style: TextStyle(color: palette.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
                Text(state.expanded ? '▲' : '▼', style: muted),
              ],
            ),
          ),
          if (state.expanded) ...[
            const SizedBox(height: 12),
            if (history != null)
              Row(
                spacing: 6,
                children: [
                  _StatTile(
                    value: '${history.total}',
                    label: 'HANDLED',
                    color: palette.textPrimary,
                    active: state.filter == HistoryFilter.all,
                    onTap: () => actions.filterBy(HistoryFilter.all),
                  ),
                  _StatTile(
                    value: '${history.resolved}',
                    label: 'RESOLVED',
                    color: palette.accentGreen,
                    active: state.filter == HistoryFilter.resolved,
                    onTap: () => actions.filterBy(HistoryFilter.resolved),
                  ),
                  _StatTile(
                    value: history.avgAcceptSeconds == null
                        ? '—'
                        : '${history.avgAcceptSeconds!.round()}s',
                    label: 'AVG ACCEPT',
                    color: palette.primary,
                    active: state.filter == HistoryFilter.fastest,
                    onTap: () => actions.filterBy(HistoryFilter.fastest),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            if (state.loading && history == null)
              Center(child: Text('Loading…', style: muted))
            else if (visible.isEmpty)
              Center(
                child: Text(
                  (history?.entries.isEmpty ?? true)
                      ? 'You have not handled any pings yet.'
                      : 'Nothing matches this view.',
                  style: muted,
                ),
              )
            else ...[
              if (state.filter != HistoryFilter.all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    state.filter == HistoryFilter.resolved
                        ? 'Showing ${visible.length} resolved'
                        : 'Showing ${visible.length} by fastest acceptance',
                    style: muted.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              for (final entry in visible) _HistoryEntry(entry: entry),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String value;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? palette.inputBg : null,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(
              color: active ? palette.primary : palette.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry});

  final ResponderPing entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = switch (entry.status) {
      PingStatus.resolved => palette.accentGreen,
      PingStatus.cancelled => palette.textSecondary,
      PingStatus.pending || PingStatus.expired => palette.danger,
      _ => palette.primary,
    };
    final muted = TextStyle(color: palette.textSecondary, fontSize: 12);
    final delay = entry.acceptDelay;
    final created = entry.createdAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: palette.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadii.sm),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '#${entry.id} · ${entry.agency}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          entry.status == PingStatus.enRoute
                              ? 'EN ROUTE'
                              : entry.status.name.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (entry.address case final address?
                        when address.isNotEmpty)
                      Text(
                        '📍 $address',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    if (created != null)
                      Text(
                        'Raised ${relativeTime(created)}'
                        '${delay == null ? '' : ' · accepted in ${formatAcceptDelay(delay)}'}',
                        style: muted,
                      ),
                    Text(
                      'From: ${entry.userEmail ?? 'anonymous'}'
                      '${entry.responderMode == null ? '' : ' · by ${entry.responderMode}'}',
                      style: muted,
                    ),
                    if (entry.note case final note? when note.trim().isNotEmpty)
                      Text(
                        '“$note”',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DutyCard extends ConsumerWidget {
  const _DutyCard({required this.responder, required this.console});

  final Responder responder;
  final ResponderConsoleState console;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final onDuty = responder.onDuty;
    // Can't go off duty with an accepted ping still open.
    final locked =
        onDuty &&
        ref.watch(
          responderQueueViewModelProvider.select((q) => q.hasActivePing),
        );
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
                onPressed: console.dutyBusy || locked
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
          if (locked) ...[
            const SizedBox(height: 6),
            Text(
              ResponderConsoleViewModel.activePingMessage,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (console.dutyError != null) ...[
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
