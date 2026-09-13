import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/emergency_profile.dart';
import '../../core/widgets/app_button.dart';
import '../view_model/emergency_profile_view_model.dart';

/// Lets the user save medical/contact details once so they travel with any
/// Ping for Help alert — matches the web platform's "Emergency profile"
/// modal, reachable from [GetHelpSheet]'s "My emergency profile" row.
/// Stored locally only (see [EmergencyProfileRepository]).
class EmergencyProfileSheet extends ConsumerStatefulWidget {
  const EmergencyProfileSheet({super.key});

  @override
  ConsumerState<EmergencyProfileSheet> createState() => _EmergencyProfileSheetState();
}

class _EmergencyProfileSheetState extends ConsumerState<EmergencyProfileSheet> {
  final _fullNameController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _nextOfKinController = TextEditingController();
  final _nextOfKinPhoneController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _bloodGroupController.dispose();
    _conditionsController.dispose();
    _allergiesController.dispose();
    _nextOfKinController.dispose();
    _nextOfKinPhoneController.dispose();
    super.dispose();
  }

  void _populate(EmergencyProfile profile) {
    _fullNameController.text = profile.fullName;
    _bloodGroupController.text = profile.bloodGroup;
    _conditionsController.text = profile.conditions;
    _allergiesController.text = profile.allergies;
    _nextOfKinController.text = profile.nextOfKin;
    _nextOfKinPhoneController.text = profile.nextOfKinPhone;
  }

  Future<void> _save() async {
    final profile = EmergencyProfile(
      fullName: _fullNameController.text.trim(),
      bloodGroup: _bloodGroupController.text.trim(),
      conditions: _conditionsController.text.trim(),
      allergies: _allergiesController.text.trim(),
      nextOfKin: _nextOfKinController.text.trim(),
      nextOfKinPhone: _nextOfKinPhoneController.text.trim(),
    );
    await ref.read(emergencyProfileViewModelProvider.notifier).save(profile);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _clear() async {
    await ref.read(emergencyProfileViewModelProvider.notifier).clear();
    _populate(EmergencyProfile.empty);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(emergencyProfileViewModelProvider);
    final profile = profileAsync.value;
    if (profile != null && !_initialized) {
      _initialized = true;
      _populate(profile);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Emergency profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Sent to the responder with your SOS, so they arrive knowing what matters. '
              'Stored only on this device.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (profileAsync.isLoading && !_initialized)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _ProfileField(label: 'FULL NAME', controller: _fullNameController, hint: 'Adaeze Okonkwo'),
              _ProfileField(label: 'BLOOD GROUP', controller: _bloodGroupController, hint: 'O+'),
              _ProfileField(label: 'CONDITIONS', controller: _conditionsController, hint: 'Asthma, diabetes'),
              _ProfileField(label: 'ALLERGIES', controller: _allergiesController, hint: 'Penicillin'),
              _ProfileField(label: 'NEXT OF KIN', controller: _nextOfKinController, hint: 'Sister'),
              _ProfileField(
                label: 'NEXT OF KIN PHONE',
                controller: _nextOfKinPhoneController,
                hint: '+234…',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: AppButton(label: 'Save profile', onPressed: _save)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(label: 'Clear', variant: AppButtonVariant.secondary, onPressed: _clear),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: AppColors.backgroundCanvas,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
