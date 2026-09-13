import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import 'emergency_profile_sheet.dart';

enum _HelpMode { ping, goToHelp }

enum _HelpCategory { hospital, police, fire, roadSafety }

/// The web platform renders these as plain emoji, not an icon font/SVG set —
/// confirmed against 911rescueme.com's live "Get Help Fast" card — so this
/// copies the exact glyphs rather than approximating with Material icons.
extension on _HelpCategory {
  String get emoji => switch (this) {
    _HelpCategory.hospital => '🏥',
    _HelpCategory.police => '🛡️',
    _HelpCategory.fire => '🔥',
    _HelpCategory.roadSafety => '🚧',
  };

  String get label => switch (this) {
    _HelpCategory.hospital => 'Hospital',
    _HelpCategory.police => 'Police',
    _HelpCategory.fire => 'Fire',
    _HelpCategory.roadSafety => 'Road Safety',
  };
}

class GetHelpSheet extends StatefulWidget {
  const GetHelpSheet({
    super.key,
    this.onDismiss,
    this.onBack,
    this.isPinnedLocation = false,
  });

  final VoidCallback? onDismiss;

  /// "Back to pin" — returns to whichever origin popup (dropped pin or
  /// "Your Location") this was opened from, instead of closing it entirely
  /// like [onDismiss] does. Falls back to [onDismiss]'s behavior when this
  /// sheet isn't opened from that popup (e.g. the standalone Get Help
  /// screen), since there's nothing to "go back" to there.
  final VoidCallback? onBack;

  /// Whether the origin is a dropped pin rather than "Your Location" — shows
  /// a warning that a ping targets the pin, not the user's live GPS position.
  final bool isPinnedLocation;

  @override
  State<GetHelpSheet> createState() => _GetHelpSheetState();
}

class _GetHelpSheetState extends State<GetHelpSheet> {
  _HelpMode? _mode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: 8,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '🚨 Get Help Fast',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                InkWell(
                  onTap:
                      widget.onDismiss ??
                      () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Choose one option',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: _OptionChip(
                    icon: Icons.sensors,
                    label: 'Ping for Help',
                    color: AppColors.danger,
                    selected: _mode == _HelpMode.ping,
                    onTap: () => setState(() => _mode = _HelpMode.ping),
                  ),
                ),
                Expanded(
                  child: _OptionChip(
                    icon: Icons.directions_car,
                    label: 'Go to Help',
                    color: AppColors.primary,
                    selected: _mode == _HelpMode.goToHelp,
                    onTap: () => setState(() => _mode = _HelpMode.goToHelp),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _mode == null
                    ? 'Pick an option above first'
                    : 'Then choose help type',
                style: TextStyle(
                  fontSize: 12,
                  color: _mode == null
                      ? AppColors.textSecondary
                      : AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _HelpCategory.values.map((category) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        onTap: _mode == null
                            ? null
                            : () => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${category.label} requested (demo)',
                                  ),
                                ),
                              ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.backgroundCanvas,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            // IntrinsicHeight + stretch (above) sizes every
                            // tile to the tallest one instead of a hardcoded
                            // height — "Road Safety" wrapping to two lines
                            // while the rest stayed on one is what made that
                            // tile look mismatched (and a fixed height too
                            // short for the wrapped case overflowed).
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  category.emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  category.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.isPinnedLocation) ...[
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.danger,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is a pinned location, not your GPS position. A ping sends responders to this pin.',
                      style: TextStyle(fontSize: 10, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              '((•)) Ping notifies responders and shares locations both ways.\n'
              '🚗 Go to Help routes you by car to the nearest facility.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'My emergency profile',
                icon: Icons.healing,
                variant: AppButtonVariant.secondary,
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const EmergencyProfileSheet(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                icon: Icons.arrow_back,
                label: 'Back to pin',
                variant: AppButtonVariant.secondary,
                onPressed:
                    widget.onBack ??
                    widget.onDismiss ??
                    () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Ping for Help" / "Go to Help" toggle chips — outlined in [color]
/// when idle, filled solid with white content once picked, so choosing one
/// visibly commits to it before the help-type grid below unlocks.
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contentColor = selected ? Colors.white : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            Icon(icon, size: 18, color: contentColor),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: contentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
