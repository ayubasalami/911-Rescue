import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/facility.dart';
import '../../core/widgets/facility_category_glyph.dart';
import 'map_legend.dart';

/// A facility's "View Info" — the web's facility modal: photo header,
/// name, category chip, contact details, About, Available Services and a
/// Get Directions button. Missing descriptions and services fall back to
/// per-category defaults, as on the web.
Future<void> showFacilityInfoDialog(
  BuildContext context, {
  required Facility facility,
  required VoidCallback onGetDirections,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      FacilityInfoDialog(facility: facility, onGetDirections: onGetDirections),
);

/// The web's fallback copy per category group — "Ikeja" swapped for
/// "Lagos", since facilities span the whole state.
const _defaults = {
  FacilityCategory.health: (
    description:
        'A registered healthcare facility providing essential medical '
        'services to the Lagos community.',
    services: [
      'General Consultation',
      'Emergency Care',
      'Pharmacy',
      'Maternity',
    ],
  ),
  FacilityCategory.police: (
    description:
        'A police facility serving the Lagos community, handling law '
        'enforcement, public safety, and crime response.',
    services: [
      'Crime Reporting',
      'Emergency Response',
      'Community Policing',
      'Traffic Enforcement',
    ],
  ),
  FacilityCategory.fire: (
    description:
        'A fire and emergency response facility providing rapid response to '
        'fires, rescues, and other emergencies.',
    services: [
      'Fire Suppression',
      'Emergency Rescue',
      'Hazmat Response',
      'Public Fire Safety Education',
    ],
  ),
  FacilityCategory.roadSafety: (
    description:
        'A Federal Road Safety Corps (FRSC) facility responsible for road '
        'safety enforcement and accident response.',
    services: [
      'Accident Response',
      'Road Safety Enforcement',
      'Vehicle Inspection',
      'Driver Education',
    ],
  ),
  FacilityCategory.other: (
    description: 'A registered facility serving the Lagos community.',
    services: ['General Services'],
  ),
};

/// The web's `--input-bg`.
const _inputBg = Color(0xFFF0F2F5);

/// The web's `--accent-green`.
const _webGreen = Color(0xFF00AA55);

class FacilityInfoDialog extends ConsumerWidget {
  const FacilityInfoDialog({
    super.key,
    required this.facility,
    required this.onGetDirections,
  });

  final Facility facility;
  final VoidCallback onGetDirections;

  /// Relative image paths are served from the API host — the web's
  /// `resolveImageUrl`.
  String? _resolveImageUrl(String apiBaseUrl) {
    final url = facility.imageUrl?.trim();
    if (url == null || url.isEmpty) return null;
    if (url.startsWith(RegExp('https?://', caseSensitive: false))) return url;
    return '$apiBaseUrl${url.startsWith('/') ? '' : '/'}$url';
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaults = _defaults[facility.category]!;
    final description = _nonBlank(facility.description) ?? defaults.description;
    final services = facility.services.isNotEmpty
        ? facility.services
        : defaults.services;
    final imageUrl = _resolveImageUrl(ref.watch(appConfigProvider).apiBaseUrl);
    final address = _nonBlank(facility.address);
    final phone = _nonBlank(facility.phone);
    final website = _nonBlank(facility.website);
    final category = facility.isPlace
        ? 'Location'
        : _nonBlank(facility.rawCategory) ?? 'Health Facility';

    const muted = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13,
      height: 1.6,
    );
    const link = TextStyle(color: AppColors.primary, fontSize: 13);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 180,
                  child: imageUrl == null
                      ? _HeaderFallback(facility: facility)
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : _HeaderFallback(facility: facility),
                          errorBuilder: (_, _, _) =>
                              _HeaderFallback(facility: facility),
                        ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facility.name,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _inputBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _inputBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          _DetailRow(
                            emoji: '📍',
                            child: Text(
                              address ?? 'Address not available',
                              style: muted.copyWith(height: 1.4),
                            ),
                          ),
                          _DetailRow(
                            emoji: '📞',
                            child: phone == null
                                ? Text('Phone not available', style: muted)
                                : InkWell(
                                    onTap: () => _open(
                                      context,
                                      Uri(
                                        scheme: 'tel',
                                        path: phone.replaceAll(
                                          RegExp(r'\s+'),
                                          '',
                                        ),
                                      ),
                                    ),
                                    child: Text(phone, style: link),
                                  ),
                          ),
                          _DetailRow(
                            emoji: '🌐',
                            child: website == null
                                ? Text('Website not available', style: muted)
                                : InkWell(
                                    onTap: () =>
                                        _open(context, Uri.parse(website)),
                                    child: const Text(
                                      'Visit Website',
                                      style: link,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SectionHeading('About'),
                    Text(description, style: muted),
                    const SizedBox(height: 18),
                    const _SectionHeading('Available Services'),
                    for (final service in services)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('•  $service', style: muted),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onGetDirections();
                        },
                        icon: const Icon(Icons.location_on_outlined, size: 16),
                        label: const Text('Get Directions'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _webGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(11),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// Shown while the photo loads, if it fails, or when there's none — the
/// category colour and crest, rather than the web's text placeholder.
class _HeaderFallback extends StatelessWidget {
  const _HeaderFallback({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final color = facility.category.legendColor;
    final crest = facility.category.crestAsset;
    return ColoredBox(
      color: color.withValues(alpha: 0.12),
      child: Center(
        child: crest != null
            ? Image.asset(crest, width: 72, height: 72)
            : facility.isPlace
            ? const Icon(
                Icons.location_on_outlined,
                size: 56,
                color: AppColors.textSecondary,
              )
            : FacilityCategoryGlyph(
                category: facility.category,
                color: color,
                size: 56,
              ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.emoji, required this.child});

  final String emoji;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 6),
      Expanded(child: child),
    ],
  );
}

/// The web's `h3`: 14px with a rule underneath.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        const Divider(height: 1),
      ],
    ),
  );
}
