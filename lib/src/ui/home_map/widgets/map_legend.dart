import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';

/// Matches the web platform's floating map legend: facility category
/// glyphs and the 6-band driving-time color ramp. Toggled on/off by the
/// 5th map control button, defaulting to visible.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundSurface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: 4,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Facilities', style: _headerStyle),
            const SizedBox(height: 6),
            for (final category in FacilityCategory.values)
              _LegendRow(icon: Icon(category.legendIcon, color: category.legendColor, size: 16), label: category.displayLabel),
            const SizedBox(height: 10),
            const Text('Driving Time', style: _headerStyle),
            const SizedBox(height: 6),
            const _LegendRow(icon: _DashedLine(), label: 'Shortest Route'),
            for (final band in TimeBand.bands)
              _LegendRow(
                icon: Container(width: 14, height: 14, color: Color(band.color)),
                label: band.rangeLabel,
              ),
          ],
        ),
      ),
    );
  }
}

const _headerStyle = TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13);

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 18, child: Center(child: icon)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 2,
      child: Row(
        children: List.generate(
          3,
          (index) => Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index == 2 ? 0 : 2),
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

extension FacilityCategoryLegend on FacilityCategory {
  IconData get legendIcon => switch (this) {
        FacilityCategory.health => Icons.add,
        FacilityCategory.other => Icons.circle,
        FacilityCategory.police => Icons.local_police,
        FacilityCategory.fire => Icons.local_fire_department,
        FacilityCategory.roadSafety => Icons.change_history,
      };

  Color get legendColor => Color(switch (this) {
        FacilityCategory.health => 0xFFD9004C,
        FacilityCategory.other => 0xFF22C55E,
        FacilityCategory.police => 0xFF0077FF,
        FacilityCategory.fire => 0xFFF59E0B,
        FacilityCategory.roadSafety => 0xFF9333EA,
      });
}
