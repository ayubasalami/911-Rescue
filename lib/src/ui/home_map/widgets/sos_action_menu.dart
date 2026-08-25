import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The expanded state of the map's SOS button: a quick "Report Incident" /
/// "Call for Help" choice, with a dismiss control replacing the FAB itself.
class SosActionMenu extends StatelessWidget {
  const SosActionMenu({
    super.key,
    required this.onReportIncident,
    required this.onCallForHelp,
    required this.onClose,
  });

  final VoidCallback onReportIncident;
  final VoidCallback onCallForHelp;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ActionPill(
          icon: Icons.chat_bubble_outline,
          label: 'Report Incident',
          color: AppColors.primary,
          onTap: onReportIncident,
        ),
        const SizedBox(height: 10),
        _ActionPill(
          icon: Icons.call,
          label: 'Call for Help - 112',
          color: AppColors.danger,
          onTap: onCallForHelp,
        ),
        const SizedBox(height: 10),
        Material(
          color: const Color(0xFF616161),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onClose,
            child: const SizedBox(
              width: 56,
              height: 56,
              child: Icon(Icons.close, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
