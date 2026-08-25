import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/facility.dart';

/// The popup shown when a facility marker is tapped — mirrors the web
/// platform's facility card (View Info / Analyze Access / Get Directions /
/// Save Facility), distinct from [AccessOriginPopup] which has no facility
/// identity of its own.
class FacilityPopupCard extends StatelessWidget {
  const FacilityPopupCard({
    super.key,
    required this.facility,
    required this.onViewInfo,
    required this.onAnalyzeAccess,
    required this.onGetDirections,
    required this.onSaveFacility,
    required this.onClose,
  });

  final Facility facility;
  final VoidCallback onViewInfo;
  final VoidCallback onAnalyzeAccess;
  final VoidCallback onGetDirections;
  final VoidCallback onSaveFacility;
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
                Expanded(
                  child: Text(
                    facility.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
            Text(
              facility.category.displayLabel.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(facility.address, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onViewInfo, child: const Text('View Info'))),
            const SizedBox(height: 8),
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
              child: ElevatedButton(
                onPressed: onGetDirections,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Get Directions'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSaveFacility,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                ),
                child: const Text('☆ Save Facility'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
