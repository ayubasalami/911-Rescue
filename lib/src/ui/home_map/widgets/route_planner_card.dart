import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics_events.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/route_point.dart';
import '../../../data/repositories/facility_repository.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../data/services/analytics_service.dart';
import '../../../data/services/place_search_service.dart';
import '../../core/widgets/app_button.dart';
import 'go_to_help_mode_bar.dart';

/// Which planner field a dropped map pin fills — the web's `start`/`end`.
enum PlannerEndpoint {
  origin('start'),
  destination('end');

  const PlannerEndpoint(this.label);

  /// The web's wording, as in "set your start point".
  final String label;
}

/// Top-left "Route Planner" panel — free-form origin/destination search,
/// matching the web platform's own route planner rather than the
/// facility-only "Get Directions" flow. The caller controls visibility —
/// [HomeMapViewModel.startRoutePlan] closes it once a route loads.
class RoutePlannerCard extends ConsumerStatefulWidget {
  const RoutePlannerCard({
    super.key,
    required this.onClose,
    required this.onGetDirections,
    required this.selectedMode,
    required this.onModeSelected,
    required this.onDropPin,
    this.initialDestination,
    this.loading = false,
  });

  /// Set when the planner is opened from a facility's Get Directions. Like
  /// the web, the destination is filled in, the start becomes the user's
  /// GPS position, and the route is calculated straight away.
  final RoutePoint? initialDestination;

  final VoidCallback onClose;

  /// A field's 📍 button — the screen enters "tap the map" mode and hands
  /// the tapped point back through [RoutePlannerCardState.placeDroppedPin].
  final ValueChanged<PlannerEndpoint> onDropPin;

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
  ConsumerState<RoutePlannerCard> createState() => RoutePlannerCardState();
}

class RoutePlannerCardState extends ConsumerState<RoutePlannerCard> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  RoutePoint? _origin;
  RoutePoint? _destination;
  bool _originFollowsUser = false;

  @override
  void initState() {
    super.initState();
    final destination = widget.initialDestination;
    if (destination != null) {
      _destination = destination;
      _destinationController.text = destination.name;
      _startFromCurrentLocation();
    }
  }

  /// The web's planner effect for a preset destination: take a GPS fix as
  /// the start and route. With no fix it just waits for the user to pick a
  /// start (no drop-pin fallback here, unlike the GPS button).
  Future<void> _startFromCurrentLocation() async {
    final result = await ref.read(locationRepositoryProvider).currentPosition();
    final position = result.position;
    if (!mounted || position == null || _origin != null) return;
    _setOrigin(
      RoutePoint(
        name: '📍 Your Location',
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      followsUser: true,
    );
    if (_destination != null && !widget.loading) _submit();
  }

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

  /// A pin dropped on the map for [endpoint]. Like the web, once both ends
  /// are set this goes straight to the route — no extra "Get Directions"
  /// tap.
  void placeDroppedPin(PlannerEndpoint endpoint, RoutePoint point) {
    switch (endpoint) {
      case PlannerEndpoint.origin:
        _setOrigin(point);
      case PlannerEndpoint.destination:
        _setDestination(point);
    }
    if (_origin != null && _destination != null && !widget.loading) _submit();
  }

  Future<void> _useCurrentLocation() async {
    final result = await ref.read(locationRepositoryProvider).currentPosition();
    final position = result.position;
    if (!mounted) return;
    // The web falls back to dropping a pin when GPS isn't available.
    if (position == null) {
      widget.onDropPin(PlannerEndpoint.origin);
      return;
    }
    _setOrigin(
      RoutePoint(
        name: 'Your Location',
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      followsUser: true,
    );
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
                onSelected: _setOrigin,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _useCurrentLocation,
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
                    _DropPinButton(
                      onTap: () => widget.onDropPin(PlannerEndpoint.origin),
                    ),
                  ],
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
                onSelected: _setDestination,
                trailing: _DropPinButton(
                  onTap: () => widget.onDropPin(PlannerEndpoint.destination),
                ),
              ),
              const SizedBox(height: 10),
              GoToHelpModeBar(
                selectedMode: widget.selectedMode,
                onModeSelected: widget.onModeSelected,
                compact: true,
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

/// The web's `.rp-pin-btn`: a muted map-pin icon after the field.
class _DropPinButton extends StatelessWidget {
  const _DropPinButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadii.full),
    child: const Padding(
      padding: EdgeInsets.fromLTRB(3, 6, 8, 6),
      child: Icon(
        Icons.location_on_outlined,
        size: 17,
        color: AppColors.textSecondary,
      ),
    ),
  );
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
  final ValueChanged<RoutePoint> onSelected;
  final Widget? trailing;

  @override
  ConsumerState<_PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends ConsumerState<_PlaceSearchField> {
  Timer? _debounce;
  List<RoutePoint>? _results;
  bool _loading = false;

  /// Set when nothing came back *and* a search failed — so a network error
  /// isn't presented as "No matches".
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    // Matches the web: nothing is searched until 2 characters — a single
    // letter matches almost everything and was firing on the first tap.
    if (query.trim().length < 2) {
      setState(() {
        _results = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;
    setState(() => _loading = true);
    // Facility matches first, then general places from OpenStreetMap —
    // same order as the web. Either source failing just drops its half.
    final (facilities, places) = await (
      ref.read(facilityRepositoryProvider).search(trimmed),
      ref.read(placeSearchServiceProvider).search(trimmed),
    ).wait;
    if (!mounted) return;
    // A slower, older request can land after a newer one — drop it rather
    // than overwrite the newer results with stale ones.
    if (widget.controller.text.trim() != trimmed) return;
    final results = [
      ...?facilities.valueOrNull?.map(RoutePoint.fromFacility),
      ...?places.valueOrNull,
    ];
    // One source failing is fine if the other found something. Empty with
    // a failure means "couldn't search", not "nothing exists" — prefer the
    // facility search's message, it's the one with network-aware wording.
    final failure = facilities.failureOrNull ?? places.failureOrNull;
    setState(() {
      _loading = false;
      _results = results;
      _error = results.isEmpty && failure != null ? failure.userMessage : null;
    });
  }

  void _select(RoutePoint point) {
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          AnalyticsEvents.searchResultSelected,
          parameters: {'source': 'route_planner'},
        );
    _debounce?.cancel();
    setState(() => _results = null);
    widget.onSelected(point);
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
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                error,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            )
          else if (_results != null)
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
                    for (final point in _results!)
                      InkWell(
                        onTap: () => _select(point),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Text(
                            point.name,
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
