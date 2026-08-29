import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../core/widgets/app_button.dart';
import 'transport_mode_button.dart';

/// The popup shown for every Accessibility Analyzer origin on the web
/// platform — "Your Location," a dropped pin, or a tapped facility — each
/// just varying [title] and [analyzeLabel].
class AccessOriginPopup extends StatelessWidget {
  const AccessOriginPopup({
    super.key,
    required this.title,
    required this.selectedMode,
    required this.onModeSelected,
    required this.analyzeLabel,
    required this.onAnalyzeAccess,
    required this.onGetHelpFast,
    required this.onClose,
  });

  final String title;
  final TransportMode selectedMode;
  final ValueChanged<TransportMode> onModeSelected;
  final String analyzeLabel;
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: analyzeLabel,
                onPressed: onAnalyzeAccess,
                variant: AppButtonVariant.success,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Get Help Fast',
                onPressed: onGetHelpFast,
                variant: AppButtonVariant.danger,
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
