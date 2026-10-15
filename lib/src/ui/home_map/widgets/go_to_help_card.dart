import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/route_point.dart';
import '../../core/widgets/app_button.dart';

/// The turn-by-turn card shown while "Go to Help" is active — bottom-
/// anchored, matching the web platform (confirmed live: the collapse
/// chevron works even before "Start" is tapped, zooming the map out to the
/// route overview and shrinking the card to a "time + destination" summary,
/// distinct from the fuller "distance to go / arrive" split shown once
/// navigation actually starts).
class GoToHelpCard extends StatelessWidget {
  const GoToHelpCard({
    super.key,
    required this.destination,
    required this.route,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onCall112,
    required this.onStart,
    required this.onSendSosInstead,
    required this.onVoiceDirections,
    required this.onClose,
    this.tracking = false,
    this.accuracyMeters,
    this.arrivedTripMinutes,
    this.offRoute = false,
    this.offRouteNotice,
    this.recalculating = false,
    this.remainingMeters,
    this.onRecalculate,
    this.onViewSteps,
    this.voiceEnabled = false,
    this.sosConfirming = false,
    this.closeConfirming = false,
    this.onRequestClose,
    this.onCancelClose,
    this.onStop,
    this.onCancelSosConfirm,
    this.onConfirmSos,
  });

  final RoutePoint destination;
  final DirectionsRoute route;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onCall112;
  final VoidCallback onStart;
  final VoidCallback onSendSosInstead;
  final VoidCallback onVoiceDirections;
  final VoidCallback onClose;

  /// Whether "Start" has been tapped — swaps in the live-navigation layout
  /// (FOLLOWING YOU header, GPS signal, Stop) in place of the preview's
  /// Start button. [onStop] is required whenever this is true.
  final bool tracking;

  /// The live GPS fix's accuracy while [tracking], for the "Weak/Good GPS
  /// signal" line — null hides that line (e.g. before the first fix).
  final double? accuracyMeters;

  /// Set once live tracking reached the destination: the card becomes the
  /// web's green "You have arrived" with the trip time and Done ([onClose]).
  final int? arrivedTripMinutes;

  /// Live tracking has left the route: the card turns pink, explains, and
  /// offers [onRecalculate] — the web tracker's off-route state.
  final bool offRoute;

  /// The off-route status line, e.g. "Still off the route — recalculating
  /// automatically…".
  final String? offRouteNotice;
  final bool recalculating;
  final VoidCallback? onRecalculate;

  /// While following, the steps sit behind the web's "☰ View turn-by-turn
  /// steps" link instead of filling the card.
  final VoidCallback? onViewSteps;

  /// Distance left along the road while tracking; the whole route's
  /// distance until the first fix.
  final double? remainingMeters;

  /// Whether spoken turn-by-turn instructions are on — flips the voice
  /// button's label between "on"/"off".
  final bool voiceEnabled;

  /// Whether "Send SOS instead" has opened the "Who do you need?"
  /// confirmation — replaces the action buttons with a category picker
  /// until [onConfirmSos] or [onCancelSosConfirm].
  final bool sosConfirming;

  /// Whether "Close" was tapped and the card is asking "Stop routing and
  /// clear the map?" — [onClose] is the confirmed teardown, [onRequestClose]
  /// opens the question, [onCancelClose] is "Keep route".
  final bool closeConfirming;
  final VoidCallback? onRequestClose;
  final VoidCallback? onCancelClose;

  final VoidCallback? onStop;
  final VoidCallback? onCancelSosConfirm;
  final ValueChanged<FacilityCategory>? onConfirmSos;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: 8,
      shadowColor: Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: arrivedTripMinutes != null
                ? context.palette.accentGreen
                : tracking && offRoute
                ? context.palette.danger
                : context.palette.primary,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: arrivedTripMinutes != null
            ? _buildArrived(context, arrivedTripMinutes!)
            : tracking
            ? (expanded
                  ? _buildTrackingExpanded(context)
                  : _buildTrackingMinimized(context))
            : (expanded ? _buildExpanded(context) : _buildMinimized(context)),
      ),
    );
  }

  Widget _buildArrived(BuildContext context, int tripMinutes) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '✓ You have arrived',
          style: TextStyle(
            color: context.palette.accentGreen,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          destination.name,
          style: TextStyle(
            color: context.palette.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Trip took $tripMinutes min',
          style: TextStyle(
            color: context.palette.textSecondary,
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 10),
        AppButton(label: 'Done', onPressed: onClose),
      ],
    );
  }

  /// The web's distance format: metres under 1 km, then one decimal km.
  static String _formatMeters(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';

  String get _toGo => _formatMeters(remainingMeters ?? route.distanceMeters);

  /// "Waiting for your GPS fix…" before the first fix; afterwards only a
  /// weak fix (worse than 100 m) is worth a line, as on the web.
  String? get _gpsLine {
    final meters = accuracyMeters;
    if (meters == null) return 'Waiting for your GPS fix…';
    if (meters > 100 && !offRoute) {
      return 'Weak GPS signal (±${meters.round()} m)';
    }
    return null;
  }

  static const _sosCategories = [
    FacilityCategory.health,
    FacilityCategory.police,
    FacilityCategory.fire,
    FacilityCategory.roadSafety,
  ];

  String _sosEmoji(FacilityCategory category) => switch (category) {
    FacilityCategory.health => '🏥',
    FacilityCategory.police => '🛡️',
    FacilityCategory.fire => '🔥',
    FacilityCategory.roadSafety => '🚧',
    FacilityCategory.other => '',
  };

  String _sosLabel(FacilityCategory category) => switch (category) {
    FacilityCategory.health => 'Hospital',
    FacilityCategory.police => 'Police',
    FacilityCategory.fire => 'Fire',
    FacilityCategory.roadSafety => 'Road Safety',
    FacilityCategory.other => 'Other',
  };

  /// The "Who do you need?" confirmation shown by "Send SOS instead" —
  /// matches the web platform, confirmed live: picking a category clears
  /// the route and hands off into a ping for that category, rather than
  /// re-routing by car.
  Widget _buildSosConfirm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.palette.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: context.palette.danger, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Who do you need?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.palette.danger,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 6,
            children: _sosCategories.map((category) {
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  onTap: () => onConfirmSos?.call(category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: context.palette.backgroundSurface,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _sosEmoji(category),
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _sosLabel(category),
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
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'This alerts responders and shares your location. The route '
            'will be cleared.',
            style: TextStyle(
              fontSize: 11,
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.neutral,
              onPressed: onCancelSosConfirm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingExpanded(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!offRoute) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: context.palette.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        offRoute ? '⚠ OFF ROUTE' : 'FOLLOWING YOU',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: offRoute
                              ? context.palette.danger
                              : context.palette.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildCollapseButton(context),
          ],
        ),
        const SizedBox(height: 8),
        if (offRoute)
          Text(
            'You have left the planned route. Recalculate from where you '
            'are now, or carry on if you know a better way.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: context.palette.textPrimary,
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _toGo,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.palette.primary,
                        ),
                      ),
                      TextSpan(
                        text: ' to go',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildArriveColumn(context),
            ],
          ),
        if (_gpsLine case final line?) ...[
          const SizedBox(height: 2),
          Text(
            line,
            style: TextStyle(
              fontSize: 11,
              color: context.palette.textSecondary,
            ),
          ),
        ],
        if (offRoute && offRouteNotice != null) ...[
          const SizedBox(height: 6),
          Text(
            offRouteNotice!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.palette.danger,
            ),
          ),
        ],
        if (offRoute) ...[
          const SizedBox(height: 10),
          AppButton(
            label: recalculating ? 'Recalculating…' : 'Recalculate route',
            onPressed: recalculating ? null : onRecalculate,
            padding: _buttonPadding,
            fontSize: 13,
          ),
        ],
        if (route.steps.isNotEmpty && onViewSteps != null && !sosConfirming)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
              onTap: onViewSteps,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '☰ View turn-by-turn steps',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.palette.primary,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _buildActions(
          context,
          primary: AppButton(
            label: 'Stop',
            variant: AppButtonVariant.plain,
            onPressed: onStop,
            padding: _buttonPadding,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// The numbered turn-by-turn list — shown inline in both the preview and
  /// the navigating layouts, matching the web card. The route is fetched
  /// once and only replaced by a recalculation after going off route.
  Widget _buildStepList(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 150),
      child: ListView.separated(
        shrinkWrap: true,
        // Without an explicit padding, ListView adds the screen's safe-area
        // inset (the notch) on its scroll axis — the gap above step 1.
        padding: const EdgeInsets.only(top: 8),
        itemCount: route.steps.length,
        separatorBuilder: (_, _) => const Divider(height: 16),
        itemBuilder: (context, index) {
          final step = route.steps[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.palette.backgroundCanvas,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.palette.primary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.instruction,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    Text(
                      '${step.distanceMeters.round()} m',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrackingMinimized(BuildContext context) {
    return InkWell(
      onTap: onToggleExpanded,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _toGo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.palette.primary,
                  ),
                ),
                Text(
                  offRoute ? 'Off route' : 'arrive ${route.formattedArrival}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onCall112,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.palette.danger,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const Icon(Icons.call, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.palette.backgroundCanvas,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: context.palette.border),
              ),
              child: Icon(
                Icons.expand_less,
                color: context.palette.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: route.formattedDuration,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: context.palette.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: ' · ${route.formattedDistance}',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.name,
                    style: TextStyle(
                      color: context.palette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildArriveColumn(context),
            const SizedBox(width: 8),
            _buildCollapseButton(context),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        _buildStepList(context),
        const SizedBox(height: 12),
        _buildActions(
          context,
          primary: AppButton(
            label: 'Start',
            onPressed: onStart,
            padding: _buttonPadding,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  static const _buttonPadding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 11,
  );

  Widget _buildArriveColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Arrive',
          style: TextStyle(fontSize: 10, color: context.palette.textSecondary),
        ),
        Text(
          route.formattedArrival,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildCollapseButton(BuildContext context) {
    return InkWell(
      onTap: onToggleExpanded,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.palette.backgroundCanvas,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: context.palette.border),
        ),
        child: Icon(
          Icons.arrow_drop_down,
          size: 22,
          color: context.palette.textSecondary,
        ),
      ),
    );
  }

  /// The web card's button stack: primary + "Send SOS instead" side by
  /// side, then full-width Voice, Call 112 and Close. While "Send SOS
  /// instead" is confirming, its category picker replaces the first two
  /// rows — Call 112 and Close stay reachable throughout.
  Widget _buildActions(BuildContext context, {required Widget primary}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sosConfirming)
          _buildSosConfirm(context)
        else ...[
          Row(
            spacing: 8,
            children: [
              Expanded(child: primary),
              Expanded(
                child: AppButton(
                  label: 'Send SOS instead',
                  variant: AppButtonVariant.danger,
                  filled: false,
                  onPressed: onSendSosInstead,
                  padding: _buttonPadding,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppButton(
            label: voiceEnabled
                ? '🔊 Voice directions on'
                : '🔇 Voice directions off',
            variant: AppButtonVariant.plain,
            onPressed: onVoiceDirections,
            padding: _buttonPadding,
            fontSize: 13,
          ),
        ],
        const SizedBox(height: 8),
        AppButton(
          label: '📞 Call 112',
          variant: AppButtonVariant.danger,
          onPressed: onCall112,
          padding: _buttonPadding,
          fontSize: 13,
        ),
        const SizedBox(height: 8),
        if (closeConfirming) ...[
          Text(
            'Stop routing and clear the map?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: AppButton(
                  label: 'Yes, clear it',
                  variant: AppButtonVariant.danger,
                  onPressed: onClose,
                  padding: _buttonPadding,
                  fontSize: 13,
                ),
              ),
              Expanded(
                child: AppButton(
                  label: 'Keep route',
                  variant: AppButtonVariant.plain,
                  onPressed: onCancelClose,
                  padding: _buttonPadding,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ] else
          AppButton(
            label: 'Close',
            variant: AppButtonVariant.plain,
            onPressed: onRequestClose,
            padding: _buttonPadding,
            fontSize: 13,
          ),
      ],
    );
  }

  Widget _buildMinimized(BuildContext context) {
    return InkWell(
      onTap: onToggleExpanded,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  route.formattedDuration,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.palette.primary,
                  ),
                ),
                Text(
                  destination.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onCall112,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.palette.danger,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const Icon(Icons.call, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.palette.backgroundCanvas,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: context.palette.border),
              ),
              child: Icon(
                Icons.expand_less,
                color: context.palette.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
