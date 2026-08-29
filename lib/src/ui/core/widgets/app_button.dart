import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum AppButtonVariant { primary, success, danger, warning, secondary, neutral }

/// The app's single button style — every button should go through this
/// instead of a bare `ElevatedButton`/`OutlinedButton`, so radius, padding,
/// and color choices stay consistent everywhere rather than each screen
/// hand-rolling its own `ElevatedButton.styleFrom(...)`.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.filled = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// Filled (solid color background, white text) vs. outlined (transparent
  /// background, colored border + text) treatment of [variant]'s color.
  /// Ignored for [AppButtonVariant.secondary] and [AppButtonVariant.neutral],
  /// which always render as their own fixed look.
  final bool filled;

  final IconData? icon;

  static const _padding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
  static const _textStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 15);
  static final _shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm));

  Color get _color => switch (variant) {
        AppButtonVariant.primary => AppColors.primary,
        AppButtonVariant.success => AppColors.success,
        AppButtonVariant.danger => AppColors.danger,
        AppButtonVariant.warning => AppColors.warning,
        AppButtonVariant.secondary => AppColors.primary,
        AppButtonVariant.neutral => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    if (variant == AppButtonVariant.secondary) {
      return _build(
        outlined: true,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.backgroundSurface,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          shape: _shape,
          padding: _padding,
          textStyle: _textStyle,
        ),
      );
    }

    // A muted, informational look — "How to Use This Map," "Data Sources &
    // Credits" — distinct from an outlined [_color] button since it's
    // always this same gray regardless of [filled].
    if (variant == AppButtonVariant.neutral) {
      return _build(
        outlined: true,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.backgroundCanvas,
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          shape: _shape,
          padding: _padding,
          textStyle: _textStyle,
        ),
      );
    }

    final color = _color;
    if (filled) {
      return _build(
        outlined: false,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: _shape,
          padding: _padding,
          textStyle: _textStyle,
        ),
      );
    }

    return _build(
      outlined: true,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        shape: _shape,
        padding: _padding,
        textStyle: _textStyle,
      ),
    );
  }

  /// Builds a plain or `.icon(...)` variant of the button depending on
  /// whether [icon] is set — an always-present but empty icon slot (e.g.
  /// `SizedBox.shrink()`) still reserves its inter-child gap and visibly
  /// shifts the label off-center, so the two constructors aren't
  /// interchangeable here.
  Widget _build({required bool outlined, required ButtonStyle style}) {
    if (icon == null) {
      return outlined
          ? OutlinedButton(onPressed: onPressed, style: style, child: Text(label))
          : ElevatedButton(onPressed: onPressed, style: style, child: Text(label));
    }
    return outlined
        ? OutlinedButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 18), label: Text(label))
        : ElevatedButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 18), label: Text(label));
  }
}
