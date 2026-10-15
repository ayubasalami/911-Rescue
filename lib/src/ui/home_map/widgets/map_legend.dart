import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../core/widgets/facility_category_glyph.dart';

/// Matches the web platform's floating map legend: facility category
/// glyphs and the travel-time colour ramp. Like the web, the time section
/// is titled and coloured for the current travel [mode], and after an
/// analysis lists the bands that actually came back ([bandMinutes]).
/// Toggled on/off by the 5th map control button, defaulting to visible.
class MapLegend extends StatelessWidget {
  const MapLegend({
    super.key,
    this.mode = TransportMode.driving,
    this.bandMinutes = const [],
  });

  final TransportMode mode;

  /// The analysis's band limits in minutes, ascending; empty for the
  /// default 0-5 … 25-30 ramp.
  final List<int> bandMinutes;

  /// (from, to) minute pairs: the analysis's own bands when there are
  /// any, otherwise the default 5-minute steps up to 30.
  List<(int, int)> _ranges() {
    final limits = bandMinutes.isNotEmpty
        ? bandMinutes
        : [for (final band in TimeBand.bands) band.maxMinutes];
    return [
      for (var i = 0; i < limits.length; i++)
        (i == 0 ? 0 : limits[i - 1], limits[i]),
    ];
  }

  // Sizes taken from the web stylesheet's mobile overrides for
  // `.info.legend` / `.legend-item` / `.legend-color` / `.legend-title`.
  @override
  Widget build(BuildContext context) {
    // No fill, just the web's `backdrop-filter: blur(5px)` frosted glass
    // over the map, its 1px #ddd border and its soft drop shadow.
    return CustomPaint(
      painter: const _OuterShadowPainter(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDDDDD)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Facilities', style: _headerStyle),
                  const SizedBox(height: 3),
                  for (final category in FacilityCategory.values)
                    _LegendRow(
                      icon: FacilityCategoryGlyph(
                        category: category,
                        color: category.legendColor,
                        size: 12,
                      ),
                      label: category.displayLabel,
                    ),
                  const SizedBox(height: 10),
                  Text(mode.timeLegendTitle, style: _headerStyle),
                  const SizedBox(height: 3),
                  const _LegendRow(
                    icon: _DashedLine(),
                    label: 'Shortest Route',
                  ),
                  for (final (from, to) in _ranges())
                    _LegendRow(
                      icon: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Color(mode.bandColor(to)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      label: '$from-$to mins',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The web's `box-shadow: 0 4px 10px #0000001a`, painted only *outside*
/// the panel. A normal shadow would also paint underneath — and since the
/// panel is see-through, that would gray out the whole legend.
class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final panel = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(panel.outerRect.inflate(40)),
      Path()..addRRect(panel),
    );
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        panel.shift(const Offset(0, 4)),
        Paint()
          ..color = const Color(0x1A000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter oldDelegate) => false;
}

const _headerStyle = TextStyle(
  color: AppColors.primary,
  fontWeight: FontWeight.bold,
  fontSize: 12,
);

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 14, child: Center(child: icon)),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
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
      width: 14,
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
