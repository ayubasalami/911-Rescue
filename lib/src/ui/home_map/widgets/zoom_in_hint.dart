import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shown in place of facility markers below the zoom threshold where
/// they'd render — matches the web platform's own "Zoom in to see
/// facilities" prompt (confirmed live), which exists for the same reason
/// this app needs it: ~2,900 Lagos-wide facilities rendered at once is an
/// unreadable wall of overlapping pins, not a map.
class ZoomInHint extends StatelessWidget {
  const ZoomInHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.full),
      elevation: 4,
      shadowColor: Colors.black26,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 16, color: AppColors.textSecondary),
            SizedBox(width: 6),
            Text(
              'Zoom in to see facilities',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
