import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A floating, translucent pill — the map stays visible through and around
/// it, rather than a solid opaque app bar pushing the map down.
class HomeMapHeader extends StatelessWidget {
  const HomeMapHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.palette.backgroundSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: context.palette.border),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/logo.png', width: 22, height: 22),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              children: [
                TextSpan(
                  text: '911 ',
                  style: TextStyle(color: context.palette.primary),
                ),
                TextSpan(
                  text: 'Rescue',
                  style: TextStyle(color: context.palette.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
