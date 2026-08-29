import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/facility.dart';
import 'map_legend.dart';

class FacilitySummarySheet extends StatelessWidget {
  const FacilitySummarySheet({super.key, required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final crestAsset = facility.category.crestAsset;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: crestAsset != null
                ? Image.asset(crestAsset, width: 48, height: 48, fit: BoxFit.cover)
                : Container(
                    width: 48,
                    height: 48,
                    color: facility.category.legendColor.withValues(alpha: 0.12),
                    child: Icon(facility.category.legendIcon, color: facility.category.legendColor, size: 24),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(facility.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
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
                Text(facility.address, style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
