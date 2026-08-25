import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The first screen of the Triage flow — a choice between calling 112
/// directly for a life-threatening emergency, or describing the incident
/// to get matched with the nearest responder.
class TriageEntrySheet extends StatelessWidget {
  const TriageEntrySheet({super.key, required this.onCall112, required this.onReportIncident});

  final VoidCallback onCall112;
  final VoidCallback onReportIncident;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, color: AppColors.success, size: 10),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('911 Rescue Triage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              InkWell(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close)),
            ],
          ),
          const Divider(height: 24),
          const Text('How can we help you right now?', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          _EntryOption(
            emoji: '🚨',
            title: 'Call 112 Now',
            description: "Life-threatening emergency — unconsciousness, severe bleeding, can't breathe.",
            color: AppColors.danger,
            onTap: onCall112,
          ),
          const SizedBox(height: 12),
          _EntryOption(
            emoji: '💬',
            title: 'Report Incident',
            description: "Describe your symptoms and we'll find the closest matching specialist.",
            color: AppColors.primary,
            onTap: onReportIncident,
          ),
        ],
      ),
    );
  }
}

class _EntryOption extends StatelessWidget {
  const _EntryOption({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
