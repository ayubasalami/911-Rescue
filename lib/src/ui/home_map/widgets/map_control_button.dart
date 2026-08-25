import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class MapControlButton extends StatelessWidget {
  const MapControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Whether this control's toggled-on state should be shown (e.g. the
  /// legend or traffic toggle while enabled).
  final bool active;

  /// Icon color when not [active] — e.g. red for a destructive action.
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: active ? Colors.white : iconColor, size: 20),
        ),
      ),
    );
  }
}
