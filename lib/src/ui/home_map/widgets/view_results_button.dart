import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Reopens a closed [AccessAnalysisSheet] without re-running the analysis —
/// matches the web platform's floating pill that appears once the sheet is
/// dismissed while an analysis is still active.
class ViewResultsButton extends StatelessWidget {
  const ViewResultsButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(AppRadii.full),
      elevation: 4,
      shadowColor: Colors.black38,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.full),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.full),
            gradient: LinearGradient(
              colors: [context.palette.primary, context.palette.success],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: context.palette.onAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'View Results',
                style: TextStyle(
                  color: context.palette.onAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
