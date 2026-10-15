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
    this.saved = false,
  });

  final Facility facility;
  final VoidCallback onViewInfo;
  final VoidCallback onAnalyzeAccess;
  final VoidCallback onGetDirections;
  final VoidCallback onSaveFacility;
  final VoidCallback onClose;

  /// Already in the saved facilities — the button then unsaves.
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final crestAsset = facility.category.crestAsset;

    return Material(
      color: context.palette.backgroundSurface,
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
                      child: Image.asset(
                        crestAsset,
                        width: double.infinity,
                        height: 130,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: onClose,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          // Matches the web card's own facility-name color
                          // (confirmed live on 911rescueme.com) — this app
                          // was rendering it in the default near-black text
                          // color instead.
                          color: context.palette.success,
                        ),
                      ),
                      Text(
                        facility.categoryLabel.toUpperCase(),
                        style: TextStyle(
                          color: context.palette.textSecondary,
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
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            if (facility.address case final address?) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: context.palette.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (facility.phone case final phone?) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.phone,
                    size: 14,
                    color: context.palette.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      phone,
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: AppButton(
                    label: 'View Info',
                    onPressed: onViewInfo,
                    filled: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 14,
                    ),
                    fontSize: 12,
                  ),
                ),
                Expanded(
                  child: AppButton(
                    label: 'Analyze Access',
                    onPressed: onAnalyzeAccess,
                    variant: AppButtonVariant.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 14,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Get Directions',
                icon: Icons.directions,
                onPressed: onGetDirections,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: saved ? '⭐ Saved' : '☆ Save Facility',
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
