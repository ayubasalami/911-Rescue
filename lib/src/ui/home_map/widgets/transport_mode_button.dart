import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';

/// Matches the web platform, which uses plain emoji for these — exact glyph
/// match rather than an approximated Material icon.
extension TransportModeEmoji on TransportMode {
  String get emoji => switch (this) {
        TransportMode.driving => '🚗',
        TransportMode.walking => '🚶',
        TransportMode.motorbike => '🏍️',
        TransportMode.cycling => '🚲',
      };

  /// Matches the web platform's Commute Mode dropdown option text.
  String get dropdownLabel => switch (this) {
        TransportMode.driving => 'Driving (Lagos Traffic)',
        TransportMode.walking => 'Walking',
        TransportMode.motorbike => 'Motorbike',
        TransportMode.cycling => 'Cycling',
      };
}

class TransportModeButton extends StatelessWidget {
  const TransportModeButton({super.key, required this.mode, required this.selected, required this.onTap});

  final TransportMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.backgroundCanvas,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: Text(mode.emoji, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}
