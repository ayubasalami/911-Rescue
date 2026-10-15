import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The SOS menu's "Report Incident" / "Call for Help" choices, shown above
/// the SOS button — which stays put and turns into the ✕ (see [SosFab]),
/// like the web, rather than this menu bringing its own close button.
class SosActionMenu extends StatelessWidget {
  const SosActionMenu({
    super.key,
    required this.onReportIncident,
    required this.onCallForHelp,
  });

  final VoidCallback onReportIncident;
  final VoidCallback onCallForHelp;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ActionPill(
          icon: Icons.chat_bubble_outline,
          label: 'Report Incident',
          color: context.palette.primary,
          onTap: onReportIncident,
        ),
        const SizedBox(height: 10),
        _ActionPill(
          icon: Icons.call,
          label: 'Call for Help - 112',
          color: context.palette.danger,
          onTap: onCallForHelp,
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // White on the SOS pink, the theme's button text on the blue.
    final foreground = color == context.palette.danger
        ? Colors.white
        : context.palette.onAccent;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadii.full),
      elevation: 4,
      shadowColor: Colors.black38,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.full),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
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
