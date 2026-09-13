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
    return Material(
      color: AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.full),
      elevation: 4,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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

extension on TransportMode {
  /// The mode bar's short label — distinct from [TransportModeEmoji.dropdownLabel]
  /// which is written for the sidebar's full "Driving (Lagos Traffic)" style text.
  String get modeBarLabel => switch (this) {
    TransportMode.driving => 'Car',
    TransportMode.motorbike => 'Okada',
    TransportMode.cycling => 'Bike',
    TransportMode.walking => 'Walk',
  };
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
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mode.emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 3),
            Text(
              mode.modeBarLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
