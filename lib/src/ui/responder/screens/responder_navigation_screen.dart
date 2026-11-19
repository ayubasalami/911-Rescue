import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/geo_point.dart';
import '../../../data/models/ping.dart';
import '../../../data/models/responder.dart';
import '../../../data/services/access_analysis_service.dart';
import '../../../data/services/voice_directions_service.dart';
import '../../../utils/route_progress.dart';
import '../../../utils/turn_announcer.dart';
import '../../home_map/controllers/map_annotation_controller.dart';
import '../view_model/responder_console_view_model.dart';
import '../view_model/responder_queue_view_model.dart';
import '../widgets/responder_ping_card.dart';

bool get _canRenderRealMap => !Platform.environment.containsKey('FLUTTER_TEST');

/// A new road route after moving this far from where the last one started.
const _rerouteAfterMeters = 60.0;

String _travelTime(double seconds) {
  final minutes = (seconds / 60).round().clamp(1, 1 << 30);
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

/// The web's "Navigating to ping #N", full screen from the start: on a
/// phone the web's in-card map is too small to drive by. The route follows
/// the responder's live position (shared by the console) in the mode they
/// chose, with spoken turns, heading-up and re-centre.
class ResponderNavigationScreen extends ConsumerStatefulWidget {
  const ResponderNavigationScreen({super.key, required this.pingId});

  final int pingId;

  @override
  ConsumerState<ResponderNavigationScreen> createState() =>
      _ResponderNavigationScreenState();
}

class _ResponderNavigationScreenState
    extends ConsumerState<ResponderNavigationScreen> {
  final _map = MapAnnotationController();
  bool _mapReady = false;
  DirectionsRoute? _route;
  GeoPoint? _routeFrom;
  String? _routeMode;
  bool _routing = false;
  bool _voiceOn = true;
  bool _headingUp = true;
  final _spokenSteps = <int>{};
  bool? _styleDark;
  mapbox.CameraViewportState? _viewport;

  /// The "both of you" view shown while the route is calculated; the move
  /// to the responder waits for it so the two animations don't fight.
  Future<void>? _overview;
  bool _framed = false;

  /// The citizen's details under the map: opened by the responder, or by
  /// itself when a voice note or note arrives mid-journey.
  bool _detailsOpen = false;
  bool? _hadVoice;
  String? _lastNote;

  /// Whether the ping has been in the queue since opening — until then an
  /// empty queue just hasn't loaded yet.
  bool _seenPing = false;
  late final VoiceDirectionsService _voice;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceDirectionsServiceProvider);
  }

  @override
  void dispose() {
    unawaited(_voice.stop());
    super.dispose();
  }

  ResponderPing? _ping(ResponderQueueState queue) =>
      queue.pings.where((ping) => ping.id == widget.pingId).firstOrNull;

  Future<void> _onMapCreated(mapbox.MapboxMap map) async {
    await _map.onMapCreated(
      map,
      dark: _styleDark ?? false,
      onFacilityTap: (_) {},
      onStartPinTap: () {},
      onDestinationTap: () {},
    );
    if (!mounted) return;
    setState(() => _mapReady = true);
  }

  /// A road route when there's none yet, the responder has moved 60 m from
  /// where it started, or they've changed how they're travelling.
  Future<void> _maybeReroute(GeoPoint from, GeoPoint to, String mode) async {
    final last = _routeFrom;
    final stale =
        _route == null ||
        mode != _routeMode ||
        last == null ||
        haversineMeters(last, from) > _rerouteAfterMeters;
    if (!stale || _routing) return;
    _routing = true;
    final result = await ref
        .read(accessAnalysisServiceProvider)
        .fetchRoute(
          origin: from,
          destination: to,
          mode: TransportMode.values.firstWhere(
            (m) => m.backendMode == mode,
            orElse: () => TransportMode.driving,
          ),
        );
    _routing = false;
    if (!mounted) return;
    if (result case Ok(:final value)) {
      final first = _route == null;
      _spokenSteps.clear();
      setState(() {
        _route = value;
        _routeFrom = from;
        _routeMode = mode;
      });
      // Once the first route is calculated, do what Re-centre does; later
      // re-routes leave the camera where the responder put it.
      if (first) unawaited(_focusOnResponder(from));
    }
  }

  void _sync(ResponderPing ping, TrackedPosition? me, String mode) {
    if (!_mapReady) return;
    unawaited(_map.syncPingTarget(ping.userPoint, ping.userAccuracy));
    unawaited(_map.syncHeadingMarker(me?.point, me?.headingDegrees));
    final route = _route;
    if (route != null) unawaited(_map.renderRoute(route.points));
    if (me == null) return;
    // While the route is calculated: both the responder and the ping.
    if (!_framed) {
      _framed = true;
      _overview = _map.flyToBounds(
        [me.point, ping.userPoint],
        padding: 80,
        maxZoom: 17,
      );
    }
    unawaited(_maybeReroute(me.point, ping.userPoint, mode));
    final heading = me.headingDegrees;
    if (_headingUp && heading != null) unawaited(_map.followHeading(heading));
    if (_voiceOn && route != null) {
      final turn = nextTurnAnnouncement(
        steps: route.steps,
        position: me.point,
        spoken: _spokenSteps,
      );
      if (turn != null) {
        unawaited(_voice.speak(turn));
      }
    }
  }

  /// A voice note or note sent after opening the map: open the details and
  /// vibrate, so it isn't missed while driving.
  void _noticeNewDetails(ResponderPing ping) {
    final hadVoice = _hadVoice;
    final lastNote = _lastNote;
    _hadVoice = ping.hasVoice;
    _lastNote = ping.note;
    if (hadVoice == null) return;
    final arrived =
        (ping.hasVoice && !hadVoice) ||
        ((ping.note ?? '').isNotEmpty && ping.note != lastNote);
    if (!arrived) return;
    unawaited(HapticFeedback.heavyImpact());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _detailsOpen = true);
    });
  }

  Future<void> _focusOnResponder(GeoPoint from) async {
    await _overview;
    // The overview's own animation runs 800 ms after it's sent.
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    final me = ref.read(responderConsoleViewModelProvider).position;
    await _map.flyTo(me?.point ?? from, zoom: 17);
  }

  void _toggleHeading() {
    setState(() => _headingUp = !_headingUp);
    unawaited(_headingUp ? _map.beginFollow() : _map.resetNorth());
  }

  void _recentre(TrackedPosition? me) {
    if (me == null) return;
    unawaited(_map.flyTo(me.point, zoom: 17));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    _styleDark ??= dark;
    unawaited(_map.setTheme(palette, dark: dark));
    final queue = ref.watch(responderQueueViewModelProvider);
    final ping = _ping(queue);
    final me = ref.watch(responderConsoleViewModelProvider).position;

    // Resolved, cancelled or taken off the queue: nothing left to navigate.
    if (ping != null) _seenPing = true;
    if (ping == null || !ping.isActive) {
      if (_seenPing || (ping != null && !ping.isActive)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.canPop()) context.pop();
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _noticeNewDetails(ping);
    final mode = queue.modeFor(ping);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(ping, me, mode);
    });
    final route = _route;
    final modeLabel = responderModes
        .firstWhere((m) => m.$1 == mode, orElse: () => responderModes.first)
        .$2;

    return Scaffold(
      appBar: AppBar(
        title: Text('Navigating to ping #${ping.id}'),
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: palette.backgroundSurface,
        actions: [
          IconButton(
            tooltip: 'Close map',
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _canRenderRealMap
                ? mapbox.MapWidget(
                    styleUri: MapAnnotationController.styleUriFor(
                      dark: _styleDark!,
                    ),
                    // Made once: a new viewport on every rebuild (each GPS
                    // fix and queue check) reads as "move the camera here",
                    // snapping it back over Re-centre and the opening fit.
                    viewport: _viewport ??= mapbox.CameraViewportState(
                      center: mapboxPointFrom(ping.userPoint),
                      zoom: 15,
                    ),
                    onMapCreated: _onMapCreated,
                  )
                : Container(color: palette.backgroundCanvas),
          ),
          Material(
            color: palette.backgroundSurface,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: me == null
                              ? Text(
                                  'Waiting for your GPS fix…',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                  ),
                                )
                              : route == null
                              ? Text(
                                  'Calculating route…',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _travelTime(route.durationSeconds),
                                      style: TextStyle(
                                        color: palette.accentGreen,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${(route.distanceMeters / 1000).toStringAsFixed(1)} '
                                      'km by road · $modeLabel'
                                      '${route.hasLiveTraffic ? '' : ' · no live traffic'}',
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        _MapToggle(
                          label: '🔊 Voice',
                          selected: _voiceOn,
                          onTap: () {
                            setState(() => _voiceOn = !_voiceOn);
                            if (!_voiceOn) {
                              unawaited(_voice.stop());
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        _MapToggle(
                          label: _headingUp ? '🧭 Heading up' : '⬆ North up',
                          selected: _headingUp,
                          onTap: _toggleHeading,
                        ),
                        const SizedBox(width: 6),
                        _MapToggle(
                          label: 'Re-centre',
                          selected: false,
                          onTap: () => _recentre(me),
                        ),
                      ],
                    ),
                    if (_headingUp)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Street names are rotated with the map. Switch to '
                          'North up to read them.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => setState(() => _detailsOpen = !_detailsOpen),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Text(
                              'Ping details',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (ping.hasVoice) ...[
                              const SizedBox(width: 8),
                              Text(
                                '🎤 Voice note',
                                style: TextStyle(
                                  color: palette.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if ((ping.medicalProfile ?? '')
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '🩺',
                                style: TextStyle(color: palette.danger),
                              ),
                            ],
                            const Spacer(),
                            Icon(
                              _detailsOpen
                                  ? Icons.expand_more
                                  : Icons.expand_less,
                              color: palette.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_detailsOpen)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.3,
                        ),
                        child: SingleChildScrollView(
                          child: ResponderPingDetails(ping: ping),
                        ),
                      ),
                    const SizedBox(height: 10),
                    _StatusButtons(ping: ping),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapToggle extends StatelessWidget {
  const _MapToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        foregroundColor: selected ? palette.primary : palette.textPrimary,
        side: BorderSide(color: selected ? palette.primary : palette.border),
        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

/// The card's next steps, here too, so the responder needn't leave the map.
class _StatusButtons extends ConsumerWidget {
  const _StatusButtons({required this.ping});

  final ResponderPing ping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final queue = ref.watch(responderQueueViewModelProvider);
    final actions = ref.read(responderQueueViewModelProvider.notifier);
    final busy = queue.busyPingId == ping.id;
    Widget button(String label, Color color, String status) => Expanded(
      child: FilledButton(
        onPressed: busy ? null : () => actions.setStatus(ping, status),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
    return Row(
      spacing: 8,
      children: [
        if (ping.status == PingStatus.accepted)
          button('On my way', palette.primary, 'en_route'),
        if (ping.status == PingStatus.enRoute)
          button('Arrived', palette.primary, 'arrived'),
        button('Resolve', palette.textSecondary, 'resolved'),
      ],
    );
  }
}
