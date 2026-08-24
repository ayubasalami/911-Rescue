import 'package:flutter/material.dart';

import '../../core/widgets/app_filter_chip.dart';

const facilityFilters = ['All', 'Health', 'Police', 'Fire'];

class FacilityFilterRow extends StatelessWidget {
  const FacilityFilterRow({super.key, required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: facilityFilters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = facilityFilters[index];
          return AppFilterChip(
            label: filter,
            selected: selected == filter,
            onTap: () => onSelected(filter),
          );
        },
      ),
    );
  }
}
