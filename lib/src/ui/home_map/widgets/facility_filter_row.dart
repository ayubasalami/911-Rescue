import 'package:flutter/material.dart';

import '../../../data/models/facility.dart';
import '../../core/widgets/app_filter_chip.dart';
import 'map_legend.dart';

/// Filters the facility pins shown on the map — null means "All".
class FacilityFilterRow extends StatelessWidget {
  const FacilityFilterRow({super.key, required this.selected, required this.onSelected});

  final FacilityCategory? selected;
  final ValueChanged<FacilityCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          AppFilterChip(label: 'All', selected: selected == null, onTap: () => onSelected(null)),
          for (final category in FacilityCategory.values) ...[
            const SizedBox(width: 8),
            AppFilterChip(
              label: category.displayLabel,
              icon: category.legendIcon,
              iconColor: category.legendColor,
              selected: selected == category,
              onTap: () => onSelected(category),
            ),
          ],
        ],
      ),
    );
  }
}
