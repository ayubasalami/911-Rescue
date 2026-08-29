import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';

enum _HelpMode { ping, goToHelp }

enum _HelpCategory { hospital, police, fire, roadSafety }

extension on _HelpCategory {
  String get label => switch (this) {
        _HelpCategory.hospital => 'Hospital',
        _HelpCategory.police => 'Police',
        _HelpCategory.fire => 'Fire',
        _HelpCategory.roadSafety => 'Road Safety',
      };

  IconData get icon => switch (this) {
        _HelpCategory.hospital => Icons.local_hospital,
        _HelpCategory.police => Icons.local_police,
        _HelpCategory.fire => Icons.local_fire_department,
        _HelpCategory.roadSafety => Icons.warning_amber,
      };
}

class GetHelpSheet extends StatefulWidget {
  const GetHelpSheet({super.key, this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  State<GetHelpSheet> createState() => _GetHelpSheetState();
}

class _GetHelpSheetState extends State<GetHelpSheet> {
  _HelpMode? _mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🚨 Get Help Fast', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Choose one option', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Ping for Help',
                  icon: Icons.sensors,
                  variant: AppButtonVariant.danger,
                  filled: _mode == _HelpMode.ping,
                  onPressed: () => setState(() => _mode = _HelpMode.ping),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Go to Help',
                  icon: Icons.directions_car,
                  variant:
                      _mode == _HelpMode.goToHelp ? AppButtonVariant.primary : AppButtonVariant.secondary,
                  onPressed: () => setState(() => _mode = _HelpMode.goToHelp),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _mode == null ? 'Pick an option above first' : 'Then choose help type',
            style: TextStyle(
              color: _mode == null ? AppColors.textSecondary : AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            children: _HelpCategory.values.map((category) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    onTap: _mode == null
                        ? null
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${category.label} requested (demo)')),
                            ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundCanvas,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            category.icon,
                            color: _mode == null ? AppColors.textSecondary : AppColors.primary,
                          ),
                          const SizedBox(height: 6),
                          Text(category.label, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            '((•)) Ping notifies responders and shares locations both ways.\n'
            '🚗 Go to Help routes you by car to the nearest facility.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Just browse the map',
              variant: AppButtonVariant.secondary,
              onPressed: widget.onDismiss ?? () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
