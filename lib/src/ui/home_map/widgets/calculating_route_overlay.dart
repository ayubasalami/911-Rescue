import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The full-screen "Calculating Route…" spinner shown while Go to Help
/// fetches or re-fetches a route — matches the web platform's loading state,
/// which appears both on the first category tap and on every mode-bar
/// change rather than leaving the old card visibly stale mid-fetch.
class CalculatingRouteOverlay extends StatelessWidget {
  const CalculatingRouteOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundCanvas.withValues(alpha: 0.9),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Calculating Route…',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Fetching live road data',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
