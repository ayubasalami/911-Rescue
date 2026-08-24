import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum AppButtonVariant { primary, danger, secondary, outline }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (variant) {
      AppButtonVariant.primary => (AppColors.primary, Colors.white, null),
      AppButtonVariant.danger => (AppColors.danger, Colors.white, null),
      AppButtonVariant.secondary => (
          AppColors.backgroundSurface,
          AppColors.primary,
          AppColors.border,
        ),
      AppButtonVariant.outline => (Colors.transparent, AppColors.danger, AppColors.danger),
    };

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        side: border == null ? null : BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }
}
