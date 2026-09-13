import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';

/// Top-right "Route active" chip shown while Go to Help is navigating.
/// Closing it cancels the whole route — confirmed against the web platform,
/// where this clears the mode bar, card, and origin selection, not just
/// the chip itself.
class RouteActiveChip extends StatelessWidget {
  const RouteActiveChip({
    super.key,
    required this.destinationName,
    required this.route,
    required this.onClose,
  });

  final String destinationName;
  final DirectionsRoute route;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Material(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        elevation: 4,
        shadowColor: Colors.black26,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🚗', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Route active',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                destinationName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${route.formattedDistance} away · ${route.formattedDuration}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              const Row(
                children: [
                  Icon(Icons.circle, size: 6, color: AppColors.success),
                  SizedBox(width: 4),
                  Text(
                    'Live traffic applied',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
