import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import 'transport_mode_button.dart' show TransportModeEmoji;

/// The Car/Okada/Bike/Walk segmented bar shown above the Go to Help card —
/// distinct from [TransportModeButton]'s compact icon-only grid used in the
/// origin popup, since the web platform shows this one with text labels.
class GoToHelpModeBar extends StatelessWidget {
  const GoToHelpModeBar({
    super.key,
    required this.selectedMode,
    required this.onModeSelected,
  });

  final TransportMode selectedMode;
  final ValueChanged<TransportMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          // mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in TransportMode.values)
              _ModeChip(
                mode: mode,
                selected: mode == selectedMode,
                onTap: () => onModeSelected(mode),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TransportMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.backgroundSurface),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(mode.emoji, style: const TextStyle(fontSize: 18))],
        ),
      ),
    );
  }
}
