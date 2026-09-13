import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../core/widgets/app_button.dart';

/// The turn-by-turn card shown while "Go to Help" is active — bottom-
/// anchored, matching the web platform (confirmed live: the collapse
/// chevron works even before "Start" is tapped, zooming the map out to the
/// route overview and shrinking the card to a "time + destination" summary,
/// distinct from the fuller "distance to go / arrive" split shown once
/// navigation actually starts).
class GoToHelpCard extends StatelessWidget {
  const GoToHelpCard({
    super.key,
    required this.destination,
    required this.route,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onCall112,
    required this.onStart,
    required this.onSendSosInstead,
    required this.onVoiceDirections,
    required this.onClose,
  });

  final Facility destination;
  final DirectionsRoute route;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onCall112;
  final VoidCallback onStart;
  final VoidCallback onSendSosInstead;
  final VoidCallback onVoiceDirections;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: 8,
      shadowColor: Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        padding: const EdgeInsets.all(14),
        child: expanded ? _buildExpanded() : _buildMinimized(),
      ),
    );
  }

  Widget _buildExpanded() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: route.formattedDuration,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: ' · ${route.formattedDistance}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Arrive',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  route.formattedArrival,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onToggleExpanded,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCanvas,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.expand_more,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: route.steps.length,
            separatorBuilder: (_, _) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final step = route.steps[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCanvas,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.instruction,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${step.distanceMeters.round()} m',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: AppButton(
                label: 'Start',
                onPressed: onStart,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                fontSize: 13,
              ),
            ),
            Expanded(
              child: AppButton(
                label: 'Send SOS instead',
                variant: AppButtonVariant.danger,
                filled: false,
                onPressed: onSendSosInstead,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: '🎙️ Voice directions off',
            variant: AppButtonVariant.neutral,
            onPressed: onVoiceDirections,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: '📞 Call 112',
            variant: AppButtonVariant.danger,
            onPressed: onCall112,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: 'Close',
            variant: AppButtonVariant.neutral,
            onPressed: onClose,
          ),
        ),
      ],
    );
  }

  Widget _buildMinimized() {
    return InkWell(
      onTap: onToggleExpanded,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  route.formattedDuration,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  destination.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onCall112,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const Icon(Icons.call, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.backgroundCanvas,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.expand_less,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
