import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/role_repository.dart';
import '../../../routing/app_router.dart';
import '../../core/view_model/role_view_model.dart';
import '../view_model/responder_auth_view_model.dart';

/// A standard sign-in screen for responders: the ID and password issued to
/// them, separate from the public Google sign-in.
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
  bool _hidePassword = true;
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
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: color, width: width),
        );
    InputDecoration field({
      required String label,
      required String hint,
      required IconData icon,
      Widget? suffix,
    }) => InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: palette.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: palette.inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(palette.border),
      enabledBorder: border(palette.border),
      focusedBorder: border(palette.primary, 1.5),
    );

    return Scaffold(
      backgroundColor: palette.backgroundSurface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/images/logo.png', height: 64),
                    const SizedBox(height: 24),
                    const Text(
                      'Responder sign in',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the responder ID and password issued to you by '
                      'your agency.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (notice != null) ...[
                      const SizedBox(height: 20),
                      _Banner(
                        icon: Icons.devices_other,
                        color: palette.danger,
                        title: 'Signed out',
                        message: notice,
                      ),
                    ],
                    const SizedBox(height: 28),
                    TextField(
                      controller: _idController,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: field(
                        label: 'Responder ID',
                        hint: 'e.g. POL-001',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: field(
                        label: 'Password',
                        hint: 'Your password',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          tooltip: _hidePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: palette.textSecondary,
                          ),
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _Banner(
                        icon: Icons.error_outline,
                        color: palette.danger,
                        message: _error!,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _signingIn ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                        ),
                        child: _signingIn
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: palette.onAccent,
                                ),
                              )
                            : const Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Forgot your password? Ask your station administrator '
                      'to reset it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Not a responder?',
                          style: TextStyle(color: palette.textSecondary),
                        ),
                        TextButton(
                          onPressed: _continueAsCitizen,
                          child: const Text('Continue as citizen'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
    this.title,
  });

  final IconData icon;
  final Color color;
  final String message;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (title != null)
                    TextSpan(
                      text: '$title. ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  TextSpan(text: message),
                ],
              ),
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
