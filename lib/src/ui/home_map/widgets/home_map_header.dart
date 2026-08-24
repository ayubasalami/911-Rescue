import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class HomeMapHeader extends StatelessWidget {
  const HomeMapHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            children: [
              TextSpan(text: '911 ', style: TextStyle(color: AppColors.primary)),
              TextSpan(text: 'Rescue', style: TextStyle(color: AppColors.success)),
            ],
          ),
        ),
      ),
    );
  }
}
