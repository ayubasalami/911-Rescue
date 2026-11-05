import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/app_user.dart';
import '../../core/view_model/auth_view_model.dart';
import '../../core/view_model/theme_mode_view_model.dart';
import '../../core/widgets/confirm_logout_dialog.dart';
import '../../get_help/widgets/emergency_profile_sheet.dart';

/// The Profile tab: sign-in, the account's dashboard, the dark mode switch
/// and the emergency (medical) profile.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({
    super.key,
    required this.scrollController,
    required this.onOpenDashboard,
  });

  final ScrollController scrollController;
  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        _AccountSection(onOpenDashboard: onOpenDashboard),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode_outlined),
          title: const Text('Dark mode'),
          value: ref.watch(themeModeProvider) == ThemeMode.dark,
          onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
        ),
        const Divider(height: 1),
        const EmergencyProfileSheet(embedded: true),
      ],
    );
  }
}

/// The web sidebar's account block: "Sign in with Google" when signed
/// out; avatar, name, email and Logout when signed in.
class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection({required this.onOpenDashboard});

  final VoidCallback onOpenDashboard;

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  /// Which sign-in is in progress, if any.
  _SignInMethod? _signingIn;

  Future<void> _signIn(_SignInMethod method) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = ref.read(authViewModelProvider.notifier);
    setState(() => _signingIn = method);
    final message = await switch (method) {
      _SignInMethod.google => auth.signIn(),
      _SignInMethod.apple => auth.signInWithApple(),
    };
    if (mounted) setState(() => _signingIn = null);
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    final user = auth.value;
    final busy = _signingIn != null || auth.isLoading;
    return Padding(
      // The web's `.sb-section`.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: user != null
          ? _Profile(
              user: user,
              onOpenDashboard: widget.onOpenDashboard,
              onLogout: () async {
                if (await confirmLogout(context)) {
                  await ref.read(authViewModelProvider.notifier).signOut();
                }
              },
            )
          : Column(
              spacing: 10,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _signIn(_SignInMethod.google),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.palette.textPrimary,
                      side: BorderSide(color: context.palette.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_signingIn == _SignInMethod.google ||
                            auth.isLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Image.asset(
                            'assets/images/google_logo.png',
                            width: 18,
                            height: 18,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _signingIn == _SignInMethod.google
                              ? 'Signing in…'
                              : 'Sign in with Google',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                // Apple requires it alongside Google on iOS (guideline 4.8);
                // behind a flag until the backend's Apple keys are live.
                if (Platform.isIOS &&
                    ref.watch(appConfigProvider).appleSignInEnabled)
                  SizedBox(
                    width: double.infinity,
                    child: SignInWithAppleButton(
                      onPressed: busy
                          ? null
                          : () => _signIn(_SignInMethod.apple),
                      text: _signingIn == _SignInMethod.apple
                          ? 'Signing in…'
                          : 'Sign in with Apple',
                      height: 44,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      style: Theme.of(context).brightness == Brightness.dark
                          ? SignInWithAppleButtonStyle.white
                          : SignInWithAppleButtonStyle.black,
                    ),
                  ),
              ],
            ),
    );
  }
}

enum _SignInMethod { google, apple }

class _Profile extends StatelessWidget {
  const _Profile({
    required this.user,
    required this.onOpenDashboard,
    required this.onLogout,
  });

  final AppUser user;
  final VoidCallback onOpenDashboard;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final name = user.name?.trim();
    final initial = (name?.isNotEmpty ?? false ? name! : user.email)
        .substring(0, 1)
        .toUpperCase();
    final picture = user.picture;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // The web's `.user-avatar`: 32px, with a 1px accent ring.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.palette.primary),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: context.palette.inputBg,
                foregroundImage: picture == null ? null : NetworkImage(picture),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: context.palette.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name != null && name.isNotEmpty)
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // The web's `.btn-dashboard`: fills the row, blue-tinted with
            // an accent border, 12px bold.
            Expanded(
              child: OutlinedButton(
                onPressed: onOpenDashboard,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0x1A0077FF),
                  foregroundColor: context.palette.primary,
                  side: BorderSide(color: context.palette.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('📊 My Dashboard'),
              ),
            ),
            const SizedBox(width: 10),
            // `.btn-logout`: plain pink text, 11px bold.
            TextButton(
              onPressed: onLogout,
              style: TextButton.styleFrom(
                foregroundColor: context.palette.danger,
                padding: const EdgeInsets.all(5),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      ],
    );
  }
}
