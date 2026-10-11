import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/route_point.dart';
import '../../../data/repositories/facility_repository.dart';
import '../../../data/repositories/location_repository.dart';
import '../../core/widgets/app_button.dart';
import 'go_to_help_mode_bar.dart';

/// Top-left "Route Planner" panel — free-form origin/destination search,
/// matching the web platform's own route planner rather than the
/// facility-only "Get Directions" flow. Stays open after "Get Directions"
/// (confirmed live: closing this panel doesn't cancel the route it
/// started), so the caller controls visibility entirely via [onClose] /
/// whatever shows this widget.
class RoutePlannerCard extends ConsumerStatefulWidget {
  const RoutePlannerCard({
    super.key,
    required this.onClose,
    required this.onGetDirections,
    required this.selectedMode,
    required this.onModeSelected,
    this.loading = false,
  });

  final VoidCallback onClose;

  /// `originFollowsUser` is true only when the origin came from "Use
  /// current location" — see [HomeMapViewModel.startRoutePlan].
  final void Function(
    RoutePoint origin,
    RoutePoint destination, {
    required bool originFollowsUser,
  })
  onGetDirections;

  final TransportMode selectedMode;
  final ValueChanged<TransportMode> onModeSelected;

  /// Shows a spinner on "Get Directions" while a route fetch is in flight
  /// — mirrors [HomeMapState.goToHelpLoading].
  final bool loading;

  @override
  ConsumerState<RoutePlannerCard> createState() => _RoutePlannerCardState();
}

class _RoutePlannerCardState extends ConsumerState<RoutePlannerCard> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  RoutePoint? _origin;
  RoutePoint? _destination;
  bool _originFollowsUser = false;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _setOrigin(RoutePoint point, {bool followsUser = false}) {
    setState(() {
      _origin = point;
      _originFollowsUser = followsUser;
      _originController.text = point.name;
    });
  }

  void _setDestination(RoutePoint point) {
    setState(() {
      _destination = point;
      _destinationController.text = point.name;
    });
  }

  void _swap() {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) return;
    setState(() {
      _origin = RoutePoint(
        name: destination.name,
        latitude: destination.latitude,
        longitude: destination.longitude,
      );
      _destination = RoutePoint(
        name: origin.name,
        latitude: origin.latitude,
        longitude: origin.longitude,
      );
      _originFollowsUser = false;
      _originController.text = _origin!.name;
      _destinationController.text = _destination!.name;
    });
  }

  void _submit() {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) return;
    widget.onGetDirections(
      origin,
      destination,
      originFollowsUser: _originFollowsUser,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _origin != null && _destination != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Material(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        elevation: 8,
        shadowColor: Colors.black26,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Route Planner',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: widget.onClose,
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
              const SizedBox(height: 8),
              _PlaceSearchField(
                controller: _originController,
                hint: 'Type or tap map to set origin',
                dotColor: AppColors.success,
                onSelected: (facility) =>
                    _setOrigin(RoutePoint.fromFacility(facility)),
                trailing: InkWell(
                  onTap: () async {
                    final result = await ref
                        .read(locationRepositoryProvider)
                        .currentPosition();
                    final position = result.position;
                    if (position == null || !context.mounted) return;
                    _setOrigin(
                      RoutePoint(
                        name: 'Your Location',
                        latitude: position.latitude,
                        longitude: position.longitude,
                      ),
                      followsUser: true,
                    );
                  },
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.my_location,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: canSubmit ? _swap : null,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSurface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.textPrimary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3.0),
                          child: Icon(
                            Icons.swap_vert,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _PlaceSearchField(
                controller: _destinationController,
                hint: 'Type or tap map to set destination',
                dotColor: AppColors.danger,
                onSelected: (facility) =>
                    _setDestination(RoutePoint.fromFacility(facility)),
              ),
              const SizedBox(height: 10),
              GoToHelpModeBar(
                selectedMode: widget.selectedMode,
                onModeSelected: widget.onModeSelected,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Get Directions',
                  variant: AppButtonVariant.success,
                  onPressed: (canSubmit && !widget.loading) ? _submit : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceSearchField extends ConsumerStatefulWidget {
  const _PlaceSearchField({
    required this.controller,
    required this.hint,
    required this.dotColor,
    required this.onSelected,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final Color dotColor;
  final ValueChanged<Facility> onSelected;
  final Widget? trailing;

  @override
  ConsumerState<_PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends ConsumerState<_PlaceSearchField> {
  Timer? _debounce;
  List<Facility>? _results;
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() => _loading = true);
    final result = await ref.read(facilityRepositoryProvider).search(trimmed);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _results = switch (result) {
        Ok(:final value) => value,
        Err() => const [],
      };
    });
  }

  void _select(Facility facility) {
    _debounce?.cancel();
    setState(() => _results = null);
    widget.onSelected(facility);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundCanvas,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    onChanged: _onChanged,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: const TextStyle(fontSize: 12),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (widget.trailing != null)
                  widget.trailing!,
              ],
            ),
          ),
          if (_results != null)
            if (_results!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'No matches',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSurface,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final facility in _results!)
                      InkWell(
                        onTap: () => _select(facility),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Text(
                            facility.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
