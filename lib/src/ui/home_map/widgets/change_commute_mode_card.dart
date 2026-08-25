import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import 'transport_mode_button.dart';

/// The small floating card that lets the user switch transport mode while
/// an Accessibility Analyzer result is active, without reopening the sheet.
class ChangeCommuteModeCard extends StatelessWidget {
  const ChangeCommuteModeCard({
    super.key,
    required this.selectedMode,
    required this.onModeSelected,
    required this.onClose,
  });

  final TransportMode selectedMode;
  final ValueChanged<TransportMode> onModeSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: 6,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Change commute mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final mode in TransportMode.values) ...[
                  Expanded(
                    child: TransportModeButton(
                      mode: mode,
                      selected: mode == selectedMode,
                      onTap: () => onModeSelected(mode),
                    ),
                  ),
                  if (mode != TransportMode.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
