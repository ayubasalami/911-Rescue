import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/facility.dart';

class FacilitySummarySheet extends StatelessWidget {
  const FacilitySummarySheet({super.key, required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(facility.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(facility.address, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
