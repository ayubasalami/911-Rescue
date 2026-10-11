import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../core/widgets/facility_category_glyph.dart';

/// Matches the web platform's floating map legend: facility category
/// glyphs and the 6-band driving-time color ramp. Toggled on/off by the
/// 5th map control button, defaulting to visible.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  // Sizes taken from the web stylesheet's mobile overrides for
  // `.info.legend` / `.legend-item` / `.legend-color` / `.legend-title`.
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundSurface.withValues(alpha: 0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 3,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Facilities', style: _headerStyle),
            const SizedBox(height: 2),
            for (final category in FacilityCategory.values)
              _LegendRow(
                icon: FacilityCategoryGlyph(
                  category: category,
                  color: category.legendColor,
                  size: 10,
                ),
                label: category.displayLabel,
              ),
            const SizedBox(height: 8),
            const Text('Driving Time', style: _headerStyle),
            const SizedBox(height: 2),
            const _LegendRow(icon: _DashedLine(), label: 'Shortest Route'),
            for (final band in TimeBand.bands)
              _LegendRow(
                icon: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color(band.color),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                label: band.rangeLabel,
              ),
          ],
        ),
      ),
    );
  }
}

const _headerStyle = TextStyle(
  color: AppColors.primary,
  fontWeight: FontWeight.bold,
  fontSize: 10,
);

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 12, child: Center(child: icon)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8.5,
              height: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
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
      width: 12,
      height: 2,
      child: Row(
        children: List.generate(
          3,
          (index) => Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index == 2 ? 0 : 1.5),
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

extension FacilityCategoryLegend on FacilityCategory {
  /// Exact hex values from 911rescueme.com's own legend SVGs — not our own
  /// palette — so pins/legend/chips share one source of truth with the web
  /// platform instead of an approximated color.
  Color get legendColor => Color(switch (this) {
    FacilityCategory.health => 0xFFE6194B,
    FacilityCategory.other => 0xFF3CB44B,
    FacilityCategory.police => 0xFF4363D8,
    FacilityCategory.fire => 0xFFF58231,
    FacilityCategory.roadSafety => 0xFF911EB4,
  });

  /// Real agency crests exist for Police and Fire — everything else has no
  /// crest and falls back to [FacilityCategoryGlyph] wherever this is used.
  String? get crestAsset => switch (this) {
    FacilityCategory.police => 'assets/images/police_logo.png',
    FacilityCategory.fire => 'assets/images/fire_logo.png',
    _ => null,
  };
}
