import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import 'transport_mode_button.dart' show TransportModeEmoji;

/// The Car/Okada/Bike/Walk mode picker, in the web platform's two looks:
/// the floating labeled-pill bar at the top of the map while a route is
/// active, and ([compact]) the emoji-only row inside the Route Planner
/// panel.
class GoToHelpModeBar extends StatelessWidget {
  const GoToHelpModeBar({
    super.key,
    required this.selectedMode,
    required this.onModeSelected,
    this.compact = false,
  });

  final TransportMode selectedMode;
  final ValueChanged<TransportMode> onModeSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final mode in TransportMode.values)
            _CompactModeChip(
              mode: mode,
              selected: mode == selectedMode,
              onTap: () => onModeSelected(mode),
            ),
        ],
      );
    }

    return Material(
      color: AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.full),
      elevation: 4,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            for (final mode in TransportMode.values)
              _PillModeChip(
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

extension on TransportMode {
  String get modeBarLabel => switch (this) {
    TransportMode.driving => 'Car',
    TransportMode.motorbike => 'Okada',
    TransportMode.cycling => 'Bike',
    TransportMode.walking => 'Walk',
  };
}

/// Top-bar chip: a pill with emoji + label — blue when selected, light
/// gray otherwise, matching the web's mobile view.
class _PillModeChip extends StatelessWidget {
  const _PillModeChip({
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
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.backgroundCanvas,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Text(mode.emoji, style: const TextStyle(fontSize: 13)),
            Text(
              mode.modeBarLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Route Planner chip: emoji only.
class _CompactModeChip extends StatelessWidget {
  const _CompactModeChip({
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
        child: Text(mode.emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
