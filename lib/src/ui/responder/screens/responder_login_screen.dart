import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/role_repository.dart';
import '../../../routing/app_router.dart';
import '../../core/view_model/role_view_model.dart';
import '../../core/widgets/app_button.dart';
import '../view_model/responder_auth_view_model.dart';
import '../widgets/console_parts.dart';

/// The web's "Responder Sign In": an ID and password issued to the
/// responder, separate from the public Google sign-in.
class ResponderLoginScreen extends ConsumerStatefulWidget {
  const ResponderLoginScreen({super.key});

  @override
  ConsumerState<ResponderLoginScreen> createState() =>
      _ResponderLoginScreenState();
}

class _ResponderLoginScreenState extends ConsumerState<ResponderLoginScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _signingIn = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _idController.text.trim();
    final password = _passwordController.text;
    if (id.isEmpty || password.isEmpty || _signingIn) return;
    setState(() {
      _signingIn = true;
      _error = null;
    });
    final message = await ref
        .read(responderAuthViewModelProvider.notifier)
        .signIn(id, password);
    if (!mounted) return;
    setState(() {
      _signingIn = false;
      _error = message;
    });
    if (message == null) context.go(AppRoute.responder);
  }

  void _continueAsCitizen() {
    ref.read(roleProvider.notifier).choose(AppRole.citizen);
    context.go(AppRoute.home);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final notice = ref.watch(responderSignOutNoticeProvider);
    return ConsolePage(
      children: [
        const GradientTitle('Responder Sign In', fontSize: 20),
        const SizedBox(height: 6),
        Text(
          'Use the responder ID and password issued to you. This is '
          'separate from the public Google sign-in.',
          style: TextStyle(color: palette.textSecondary, fontSize: 13),
        ),
        if (notice != null) ...[
          const SizedBox(height: 14),
          ConsoleSection(
            borderColor: palette.danger,
            background: palette.danger.withValues(alpha: 0.06),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Signed out. ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: notice),
                ],
              ),
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
        const SizedBox(height: 18),
        TextField(
          controller: _idController,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'Responder ID (e.g. POL-001)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: palette.danger, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: _signingIn ? 'Signing in…' : 'Sign In',
          onPressed: _signingIn ? null : _submit,
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: _continueAsCitizen,
          child: const Text('← Continue as citizen instead'),
        ),
      ],
    );
  }
}
