import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/geo_point.dart';

String _formatPopulation(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String _formatEta(Duration eta) {
  if (eta.inHours >= 1) return 'Est. ${eta.inHours} hr ${eta.inMinutes % 60} mins';
  return 'Est. ${eta.inMinutes} mins';
}

/// Mirrors the web platform's "Real-Time Analysis" results sheet: reachable
/// count + population stats, the closest routed facility, and every
/// reachable facility grouped by time band with an in-place expand-to-route
/// interaction on each row.
class AccessAnalysisSheet extends StatefulWidget {
  const AccessAnalysisSheet({
    super.key,
    required this.result,
    required this.onMapRoute,
    required this.onDirections,
    required this.onClose,
  });

  final AccessAnalysisResult result;
  final void Function(GeoPoint destination) onMapRoute;
  final void Function(GeoPoint destination) onDirections;
  final VoidCallback onClose;

  @override
  State<AccessAnalysisSheet> createState() => _AccessAnalysisSheetState();
}

class _AccessAnalysisSheetState extends State<AccessAnalysisSheet> {
  String? _expandedFacilityId;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.backgroundSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Real-Time Analysis (${result.mode.label})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  InkWell(onTap: widget.onClose, child: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'REACHABLE',
                      value: '${result.reachableCount}',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'POPULATION',
                      value: result.population == null ? 'N/A' : _formatPopulation(result.population!),
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              if (result.closest != null) ...[
                const SizedBox(height: 12),
                _ClosestFacilityCard(reachable: result.closest!),
              ],
              const SizedBox(height: 20),
              const Text(
                'FACILITIES IN RANGE (TAP TO VIEW)',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              if (result.reachableCount == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No facilities reachable within the time threshold.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              for (final band in TimeBand.bands)
                if (result.byBand[band]?.isNotEmpty ?? false) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(
                      band.label.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                    ),
                  ),
                  for (final entry in result.byBand[band]!)
                    _FacilityRow(
                      entry: entry,
                      expanded: _expandedFacilityId == entry.facility.id,
                      onTap: () => setState(
                        () => _expandedFacilityId = _expandedFacilityId == entry.facility.id ? null : entry.facility.id,
                      ),
                      onMapRoute: () => widget.onMapRoute(
                        GeoPoint(latitude: entry.facility.latitude, longitude: entry.facility.longitude),
                      ),
                      onDirections: () => widget.onDirections(
                        GeoPoint(latitude: entry.facility.latitude, longitude: entry.facility.longitude),
                      ),
                    ),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCanvas,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ClosestFacilityCard extends StatelessWidget {
  const _ClosestFacilityCard({required this.reachable});

  final ReachableFacility reachable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCanvas,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: const Border(left: BorderSide(color: AppColors.warning, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CLOSEST FACILITY (ROUTED)',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(reachable.facility.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(_formatEta(reachable.eta), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FacilityRow extends StatelessWidget {
  const _FacilityRow({
    required this.entry,
    required this.expanded,
    required this.onTap,
    required this.onMapRoute,
    required this.onDirections,
  });

  final ReachableFacility entry;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onMapRoute;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCanvas,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: const Border(left: BorderSide(color: AppColors.success, width: 3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(entry.facility.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    entry.facility.category.displayLabel,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Straight-line: ${entry.straightLineKm.toStringAsFixed(2)} km',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: onMapRoute, child: const Text('Map Route'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: onDirections, child: const Text('Directions'))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
