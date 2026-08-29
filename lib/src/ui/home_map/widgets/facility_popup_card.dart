import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/facility.dart';
import '../../core/widgets/app_button.dart';
import 'map_legend.dart';

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
    final crestAsset = facility.category.crestAsset;

    return Material(
      color: AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: 8,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (crestAsset != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: Image.asset(crestAsset, width: double.infinity, height: 130, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: onClose,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facility.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                    ],
                  ),
                ),
                if (crestAsset == null)
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
            SizedBox(
              width: double.infinity,
              child: AppButton(label: 'View Info', onPressed: onViewInfo, filled: false),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Analyze Access',
                onPressed: onAnalyzeAccess,
                variant: AppButtonVariant.success,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppButton(label: 'Get Directions', onPressed: onGetDirections),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: '☆ Save Facility',
                onPressed: onSaveFacility,
                variant: AppButtonVariant.warning,
                filled: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
