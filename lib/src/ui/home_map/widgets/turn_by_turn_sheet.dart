import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';

/// Numbered turn-by-turn steps from Mapbox Directions, matching the web
/// platform's "Turn-by-Turn Directions" modal.
class TurnByTurnSheet extends StatelessWidget {
  const TurnByTurnSheet({super.key, required this.steps});

  final List<DirectionsStep> steps;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.backgroundSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
          ),
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: steps.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 24),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Row(
                  children: [
                    const Expanded(
                      child: Text('Turn-by-Turn Directions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    InkWell(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close)),
                  ],
                );
              }
              final step = steps[index - 1];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$index.', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.instruction, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          'Continue for ${step.distanceMeters.round()}m',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
