import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../core/widgets/app_button.dart';
import '../view_model/home_map_view_model.dart';
import 'transport_mode_button.dart';

const _sectionHeaderStyle = TextStyle(
  color: AppColors.textSecondary,
  fontWeight: FontWeight.bold,
  fontSize: 12,
  letterSpacing: 0.5,
);

Future<void> _openLink(BuildContext context, String url) async {
  final launched = await launchUrl(Uri.parse(url));
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link.')));
  }
}

/// The web platform's left sidebar (search, map layers, Accessibility
/// Analyzer defaults, account), reused as a slide-in drawer on mobile rather
/// than a plain links menu — opened from the map's hamburger button.
///
/// Search, "Lagos Boundary," "Live Traffic," "How to Use This Map," and
/// "Data Sources & Credits" are UI-only for now (no backing data/logic
/// exists yet); the facility-category filter, the Emergency Facilities
/// visibility toggle, the Accessibility Analyzer defaults, Clear Analysis,
/// and every footer link are wired to real state/actions.
class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key, required this.onUseCurrentLocation, required this.onClearAnalysis});

  /// Reuses the same recenter-on-user flow as the map's own "My Location"
  /// side button — that flow needs the screen's MapAnnotationController, so
  /// it's passed in rather than duplicated here.
  final VoidCallback onUseCurrentLocation;

  /// Reuses the same cancel-analysis flow as the map's trash-icon side
  /// button, for the same reason.
  final VoidCallback onClearAnalysis;

  static const _thresholdOptionsMinutes = [15, 30, 45, 60];

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeMapViewModelProvider).value;
    final notifier = ref.read(homeMapViewModelProvider.notifier);

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.78,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              onDarkMode: () => _comingSoon(context, 'Dark mode'),
              onClose: () => Scaffold.of(context).closeDrawer(),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _comingSoon(context, 'Sign in'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/google_logo.png', width: 18, height: 18),
                      const SizedBox(width: 8),
                      const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            _SearchSection(
              onUseCurrentLocation: () {
                Scaffold.of(context).closeDrawer();
                onUseCurrentLocation();
              },
              onSearch: () => _comingSoon(context, 'Facility search'),
            ),
            const Divider(height: 1),
            _MapLayersSection(
              selectedFilter: state?.selectedFilter,
              onFilterChanged: notifier.selectFilter,
              showEmergencyFacilities: state?.showEmergencyFacilities ?? true,
              onToggleEmergencyFacilities: notifier.toggleEmergencyFacilitiesLayer,
              onLagosBoundaryTap: () => _comingSoon(context, 'Lagos Boundary layer'),
              onLiveTrafficTap: () => _comingSoon(context, 'Live traffic layer'),
            ),
            const Divider(height: 1),
            _AnalyzerDefaultsSection(
              selectedMode: state?.selectedTransportMode ?? TransportMode.driving,
              onModeChanged: notifier.setSelectedMode,
              thresholdMinutes: state?.analysisThresholdMinutes ?? kAccessAnalysisThresholdMinutes,
              onThresholdChanged: notifier.setAnalysisThreshold,
              onClearAnalysis: () {
                Scaffold.of(context).closeDrawer();
                onClearAnalysis();
              },
            ),
            _HelpLinksSection(
              onHowToUse: () => _comingSoon(context, 'How to Use This Map'),
              onDataSources: () => _comingSoon(context, 'Data Sources & Credits'),
            ),
            const Divider(height: 1),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onDarkMode, required this.onClose});

  final VoidCallback onDarkMode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: Row(
        children: [
          Image.asset('assets/images/logo_black.png', width: 40, height: 38),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    children: [
                      TextSpan(text: '911 ', style: TextStyle(color: AppColors.primary)),
                      TextSpan(text: 'Rescue', style: TextStyle(color: AppColors.success)),
                    ],
                  ),
                ),
                const Text('Emergency Finder', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.dark_mode_outlined, size: 18),
            onPressed: onDarkMode,
            tooltip: 'Toggle dark mode',
            style: IconButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: const CircleBorder(),
              foregroundColor: AppColors.primary,
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: onClose, tooltip: 'Close menu'),
        ],
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({required this.onUseCurrentLocation, required this.onSearch});

  final VoidCallback onUseCurrentLocation;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SEARCH FACILITY', style: _sectionHeaderStyle),
          const SizedBox(height: 8),
          TextField(
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'Facilities name or address',
              filled: true,
              fillColor: AppColors.backgroundCanvas,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Use Current Location',
              onPressed: onUseCurrentLocation,
              filled: false,
              icon: Icons.my_location,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapLayersSection extends StatelessWidget {
  const _MapLayersSection({
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.showEmergencyFacilities,
    required this.onToggleEmergencyFacilities,
    required this.onLagosBoundaryTap,
    required this.onLiveTrafficTap,
  });

  final FacilityCategory? selectedFilter;
  final ValueChanged<FacilityCategory?> onFilterChanged;
  final bool showEmergencyFacilities;
  final VoidCallback onToggleEmergencyFacilities;
  final VoidCallback onLagosBoundaryTap;
  final VoidCallback onLiveTrafficTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MAP LAYERS', style: _sectionHeaderStyle),
          const SizedBox(height: 8),
          const Text('Filter by Type:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          DropdownButtonFormField<FacilityCategory?>(
            initialValue: selectedFilter,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.backgroundCanvas,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Facilities')),
              for (final category in FacilityCategory.values)
                DropdownMenuItem(value: category, child: Text(category.displayLabel)),
            ],
            onChanged: onFilterChanged,
          ),
          const SizedBox(height: 12),
          _LayerRow(label: 'Lagos Boundary', value: true, onChanged: (_) => onLagosBoundaryTap()),
          _LayerRow(
            label: 'Emergency Facilities',
            value: showEmergencyFacilities,
            onChanged: (_) => onToggleEmergencyFacilities(),
          ),
          _LayerRow(label: 'Live Traffic', value: false, onChanged: (_) => onLiveTrafficTap()),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.backgroundCanvas, borderRadius: BorderRadius.circular(AppRadii.sm)),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.trailing,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(label),
      ),
    );
  }
}

class _AnalyzerDefaultsSection extends StatelessWidget {
  const _AnalyzerDefaultsSection({
    required this.selectedMode,
    required this.onModeChanged,
    required this.thresholdMinutes,
    required this.onThresholdChanged,
    required this.onClearAnalysis,
  });

  final TransportMode selectedMode;
  final ValueChanged<TransportMode> onModeChanged;
  final int thresholdMinutes;
  final ValueChanged<int> onThresholdChanged;
  final VoidCallback onClearAnalysis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACCESSIBILITY ANALYZER', style: _sectionHeaderStyle),
          const SizedBox(height: 8),
          const Text('Commute Mode:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          DropdownButtonFormField<TransportMode>(
            initialValue: selectedMode,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.backgroundCanvas,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              for (final mode in TransportMode.values)
                DropdownMenuItem(value: mode, child: Text('${mode.emoji} ${mode.dropdownLabel}')),
            ],
            onChanged: (mode) {
              if (mode != null) onModeChanged(mode);
            },
          ),
          const SizedBox(height: 12),
          const Text('Max Time Threshold:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          DropdownButtonFormField<int>(
            initialValue: thresholdMinutes,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.backgroundCanvas,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              for (final minutes in HomeDrawer._thresholdOptionsMinutes)
                DropdownMenuItem(value: minutes, child: Text('$minutes Minutes')),
            ],
            onChanged: (minutes) {
              if (minutes != null) onThresholdChanged(minutes);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Clear Analysis',
              onPressed: onClearAnalysis,
              variant: AppButtonVariant.danger,
              filled: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpLinksSection extends StatelessWidget {
  const _HelpLinksSection({required this.onHowToUse, required this.onDataSources});

  final VoidCallback onHowToUse;
  final VoidCallback onDataSources;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'How to Use This Map',
              onPressed: onHowToUse,
              variant: AppButtonVariant.neutral,
              icon: Icons.help_outline,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Data Sources & Credits',
              onPressed: onDataSources,
              variant: AppButtonVariant.neutral,
              icon: Icons.info_outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openLink(context, 'https://bwanalytics.com.ng/'),
                  child: const Text(
                    'Made by BW Analytics',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _openLink(context, 'https://www.linkedin.com/company/bwanalytics/'),
                child: Image.asset(
                  'assets/images/linkedin_icon.png',
                  width: 22,
                  height: 22,
                  color: AppColors.textSecondary,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => _openLink(context, 'https://wa.me/2348154225124'),
                child: Image.asset(
                  'assets/images/whatsapp_icon.png',
                  width: 22,
                  height: 22,
                  color: AppColors.textSecondary,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _openLink(context, 'mailto:ogdi@bwanalytics.com'),
            child: const Text('ogdi@bwanalytics.com', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          GestureDetector(
            onTap: () => _openLink(context, 'tel:+2348154225124'),
            child: const Text('+234 815 422 5124', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
