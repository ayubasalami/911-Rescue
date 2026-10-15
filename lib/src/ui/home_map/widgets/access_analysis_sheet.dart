import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../core/widgets/app_button.dart';

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
  if (eta.inHours >= 1) {
    return 'Est. ${eta.inHours} hr ${eta.inMinutes % 60} mins';
  }
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
    required this.categories,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onMapRoute,
    required this.onViewInfo,
    required this.onClose,
  });

  final AccessAnalysisResult result;

  /// The facility types on the map, for the web's "Facility type" pills.
  final List<FacilityCategory> categories;

  /// The map's category filter (null = All) — picking a pill changes it and
  /// re-runs the analysis for that type.
  final FacilityCategory? selectedFilter;
  final ValueChanged<FacilityCategory?> onFilterChanged;

  /// Takes the whole [Facility], not just its point — the caller routes
  /// this into the same Go to Help card used elsewhere, which needs the
  /// facility's name/category to display.
  final void Function(Facility facility) onMapRoute;

  /// The web's "View Info": the facility info dialog.
  final void Function(Facility facility) onViewInfo;
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
          decoration: BoxDecoration(
            color: context.palette.backgroundSurface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadii.lg),
            ),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: widget.onClose,
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
              if (widget.categories.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'FACILITY TYPE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.palette.textSecondary,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TypePill(
                      label: 'All',
                      selected: widget.selectedFilter == null,
                      onTap: () => widget.onFilterChanged(null),
                    ),
                    for (final category in widget.categories)
                      _TypePill(
                        label: category.displayLabel,
                        selected: widget.selectedFilter == category,
                        onTap: () => widget.onFilterChanged(category),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'REACHABLE',
                      value: '${result.reachableCount}',
                      color: context.palette.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'POPULATION',
                      value: result.population == null
                          ? 'N/A'
                          : _formatPopulation(result.population!),
                      color: context.palette.danger,
                    ),
                  ),
                ],
              ),
              if (result.closest != null) ...[
                const SizedBox(height: 12),
                _ClosestFacilityCard(reachable: result.closest!),
              ],
              const SizedBox(height: 20),
              Text(
                'FACILITIES IN RANGE (TAP TO VIEW)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.palette.textSecondary,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (result.reachableCount == 0)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No facilities reachable within the time threshold.',
                    style: TextStyle(color: context.palette.textSecondary),
                  ),
                ),
              for (final (index, band) in TimeBand.bands.indexed)
                if (result.byBand[band]?.isNotEmpty ?? false) ...[
                  _BandHeading(
                    // The web: "Within 5 mins" for the first band, then
                    // "5 - 10 mins", "10 - 15 mins"…
                    label: index == 0
                        ? 'Within ${band.maxMinutes} mins'
                        : '${TimeBand.bands[index - 1].maxMinutes} - '
                              '${band.maxMinutes} mins',
                  ),
                  for (final entry in result.byBand[band]!)
                    _FacilityRow(
                      entry: entry,
                      expanded: _expandedFacilityId == entry.facility.id,
                      onTap: () => setState(
                        () => _expandedFacilityId =
                            _expandedFacilityId == entry.facility.id
                            ? null
                            : entry.facility.id,
                      ),
                      onMapRoute: () => widget.onMapRoute(entry.facility),
                      onViewInfo: () => widget.onViewInfo(entry.facility),
                    ),
                ],
            ],
          ),
        );
      },
    );
  }
}

/// The web's `commute-pill` used for the "Facility type" filter.
class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? context.palette.primary : context.palette.border,
      ),
    );
    return Material(
      color: selected ? context.palette.primary : context.palette.inputBg,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? context.palette.onAccent
                  : context.palette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A time band's heading: the web's blue-tinted strip with a clock.
class _BandHeading extends StatelessWidget {
  const _BandHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: context.palette.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        spacing: 6,
        children: [
          Icon(Icons.schedule, size: 13, color: context.palette.primary),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.palette.primary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.backgroundCanvas,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
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
        color: context.palette.backgroundCanvas,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border(
          left: BorderSide(color: context.palette.warning, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLOSEST FACILITY (ROUTED)',
            style: TextStyle(
              fontSize: 11,
              color: context.palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reachable.facility.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            _formatEta(reachable.eta),
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
            ),
          ),
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
    required this.onViewInfo,
  });

  final ReachableFacility entry;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onMapRoute;
  final VoidCallback onViewInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.palette.backgroundCanvas,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border(
          left: BorderSide(color: context.palette.success, width: 3),
        ),
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
                    child: Text(
                      entry.facility.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    entry.facility.rawCategory ?? entry.facility.categoryLabel,
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: context.palette.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Straight-line: ${entry.straightLineKm.toStringAsFixed(2)} km',
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Map Route',
                        onPressed: onMapRoute,
                        filled: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: 'View Info',
                        onPressed: onViewInfo,
                        filled: false,
                      ),
                    ),
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
