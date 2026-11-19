import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/responder.dart';
import '../../../data/repositories/role_repository.dart';
import '../../../routing/app_router.dart';
import '../../core/view_model/role_view_model.dart';
import '../view_model/responder_auth_view_model.dart';
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
        TextButton(
          onPressed: () {
            ref.read(roleProvider.notifier).choose(AppRole.citizen);
            context.go(AppRoute.home);
          },
          child: const Text('← Switch to citizen'),
        ),
      ],
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
