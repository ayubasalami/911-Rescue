import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum TransportMode { driving, walking, motorbike, cycling }

extension on TransportMode {
  IconData get icon => switch (this) {
        TransportMode.driving => Icons.directions_car_rounded,
        TransportMode.walking => Icons.directions_walk_rounded,
        TransportMode.motorbike => Icons.two_wheeler_rounded,
        TransportMode.cycling => Icons.pedal_bike_rounded,
      };
}

/// Mirrors the web platform's "Your Location" map popup: a transport-mode
/// picker feeding an accessibility analysis, plus a shortcut into the SOS flow.
class YourLocationCard extends StatelessWidget {
  const YourLocationCard({
    super.key,
    required this.selectedMode,
    required this.onModeSelected,
    required this.onAnalyzeAccess,
    required this.onGetHelpFast,
    required this.onClose,
  });

  final TransportMode selectedMode;
  final ValueChanged<TransportMode> onModeSelected;
  final VoidCallback onAnalyzeAccess;
  final VoidCallback onGetHelpFast;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: 8,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Your Location',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final mode in TransportMode.values) ...[
                  Expanded(child: _ModeButton(mode: mode, selected: mode == selectedMode, onTap: () => onModeSelected(mode))),
                  if (mode != TransportMode.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAnalyzeAccess,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                child: const Text('Analyze Access'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onGetHelpFast,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: const Text('Get Help Fast'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.mode, required this.selected, required this.onTap});

  final TransportMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.backgroundCanvas,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: Icon(mode.icon, color: selected ? Colors.white : AppColors.textSecondary, size: 22),
        ),
      ),
    );
  }
}
