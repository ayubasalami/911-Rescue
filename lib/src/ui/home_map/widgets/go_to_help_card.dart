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
      color: AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: 8,
      shadowColor: Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        padding: const EdgeInsets.all(14),
        child: tracking
            ? (expanded ? _buildTrackingExpanded() : _buildTrackingMinimized())
            : (expanded ? _buildExpanded() : _buildMinimized()),
      ),
    );
  }

  String _gpsSignalLabel(double meters) {
    final rounded = meters.round();
    return meters <= 30
        ? 'Good GPS signal (±$rounded m)'
        : 'Weak GPS signal (±$rounded m)';
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
  Widget _buildSosConfirm() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.danger, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Who do you need?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
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
                      color: AppColors.backgroundSurface,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: AppColors.border),
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
          const Text(
            'This alerts responders and shares your location. The route '
            'will be cleared.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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

  Widget _buildTrackingExpanded() {
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
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'FOLLOWING YOU',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildCollapseButton(),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: route.formattedDistance,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const TextSpan(
                      text: ' to go',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildArriveColumn(),
          ],
        ),
        if (accuracyMeters != null) ...[
          const SizedBox(height: 2),
          Text(
            _gpsSignalLabel(accuracyMeters!),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Divider(height: 1),
        _buildStepList(),
        const SizedBox(height: 12),
        _buildActions(
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
  /// the navigating layouts, matching the web card. While tracking, [route]
  /// is re-fetched from the live position, so step 1 is always "what to do
  /// now".
  Widget _buildStepList() {
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
                  color: AppColors.backgroundCanvas,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${step.distanceMeters.round()} m',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
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

  Widget _buildTrackingMinimized() {
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
                  route.formattedDistance,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'arrive ${route.formattedArrival}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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
                color: AppColors.danger,
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
                color: AppColors.backgroundCanvas,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.expand_less,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded() {
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
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: ' · ${route.formattedDistance}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildArriveColumn(),
            const SizedBox(width: 8),
            _buildCollapseButton(),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        _buildStepList(),
        const SizedBox(height: 12),
        _buildActions(
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

  Widget _buildArriveColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'Arrive',
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        Text(
          route.formattedArrival,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildCollapseButton() {
    return InkWell(
      onTap: onToggleExpanded,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.backgroundCanvas,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(
          Icons.arrow_drop_down,
          size: 22,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// The web card's button stack: primary + "Send SOS instead" side by
  /// side, then full-width Voice, Call 112 and Close. While "Send SOS
  /// instead" is confirming, its category picker replaces the first two
  /// rows — Call 112 and Close stay reachable throughout.
  Widget _buildActions({required Widget primary}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sosConfirming)
          _buildSosConfirm()
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
          const Text(
            'Stop routing and clear the map?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
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

  Widget _buildMinimized() {
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  destination.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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
                color: AppColors.danger,
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
                color: AppColors.backgroundCanvas,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.expand_less,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
