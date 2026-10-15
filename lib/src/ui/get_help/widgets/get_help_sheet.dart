import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/analytics_events.dart';
import '../../../core/app_failure.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/emergency_profile.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/geo_point.dart';
import '../../../data/models/ping.dart';
import '../../../data/repositories/active_ping_repository.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../data/services/access_analysis_service.dart';
import '../../../data/services/analytics_service.dart';
import '../../../data/services/geocoding_service.dart';
import '../../../data/services/ping_service.dart';
import '../../../utils/route_progress.dart';
import '../../core/widgets/app_button.dart';
import '../view_model/emergency_profile_view_model.dart';
import 'emergency_profile_sheet.dart';

enum _HelpMode { ping, goToHelp }

enum _HelpCategory { hospital, police, fire, roadSafety }

/// The web platform renders these as plain emoji, not an icon font/SVG set —
/// confirmed against 911rescueme.com's live "Get Help Fast" card — so this
/// copies the exact glyphs rather than approximating with Material icons.
extension on _HelpCategory {
  String get emoji => switch (this) {
    _HelpCategory.hospital => '🏥',
    _HelpCategory.police => '🛡️',
    _HelpCategory.fire => '🔥',
    _HelpCategory.roadSafety => '🚧',
  };

  String get label => switch (this) {
    _HelpCategory.hospital => 'Hospital',
    _HelpCategory.police => 'Police',
    _HelpCategory.fire => 'Fire',
    _HelpCategory.roadSafety => 'Road Safety',
  };

  /// The full agency name shown on the "Finding a responder" card — the web
  /// platform's own ping API returns this exact longer form (e.g. "Health
  /// Facilities" for the "Hospital" tile) rather than the short tile label.
  String get agencyLabel => switch (this) {
    _HelpCategory.hospital => 'Health Facilities',
    _HelpCategory.police => 'Police',
    _HelpCategory.fire => 'Fire & Emergency',
    _HelpCategory.roadSafety => 'Road Safety',
  };

  FacilityCategory get facilityCategory => switch (this) {
    _HelpCategory.hospital => FacilityCategory.health,
    _HelpCategory.police => FacilityCategory.police,
    _HelpCategory.fire => FacilityCategory.fire,
    _HelpCategory.roadSafety => FacilityCategory.roadSafety,
  };

  /// `POST /api/ping`'s `agency` field — see [PingAgencyApi.apiValue] for
  /// the exact strings the backend expects.
  PingAgency get pingAgency => switch (this) {
    _HelpCategory.hospital => PingAgency.health,
    _HelpCategory.police => PingAgency.police,
    _HelpCategory.fire => PingAgency.fire,
    _HelpCategory.roadSafety => PingAgency.roadSafety,
  };
}

/// The reverse of `_HelpCategory.facilityCategory` above — for
/// [GetHelpSheet.initialPingCategory], which arrives as a [FacilityCategory]
/// since that's what Go to Help's "Who do you need?" confirmation already
/// works in. [FacilityCategory.other] has no SOS category on the web
/// platform, so it maps to null.
extension on FacilityCategory {
  _HelpCategory? get _helpCategory => switch (this) {
    FacilityCategory.health => _HelpCategory.hospital,
    FacilityCategory.police => _HelpCategory.police,
    FacilityCategory.fire => _HelpCategory.fire,
    FacilityCategory.roadSafety => _HelpCategory.roadSafety,
    FacilityCategory.other => null,
  };
}

class GetHelpSheet extends ConsumerStatefulWidget {
  const GetHelpSheet({
    super.key,
    this.onDismiss,
    this.onBack,
    this.isPinnedLocation = false,
    this.origin,
    this.onPingActiveChanged,
    this.onResponderTrack,
    this.onGoToHelp,
    this.initialPingCategory,
  });

  final VoidCallback? onDismiss;

  /// "Back to pin" — returns to whichever origin popup (dropped pin or
  /// "Your Location") this was opened from, instead of closing it entirely
  /// like [onDismiss] does. Falls back to [onDismiss]'s behavior when this
  /// sheet isn't opened from that popup (e.g. the standalone Get Help
  /// screen), since there's nothing to "go back" to there.
  final VoidCallback? onBack;

  /// Whether the origin is a dropped pin rather than "Your Location" — shows
  /// a warning that a ping targets the pin, not the user's live GPS position.
  final bool isPinnedLocation;

  /// The point a ping targets — used to reverse-geocode the "Address sent"
  /// line. Nullable since the standalone `/get-help` route renders this
  /// sheet with no map context at all.
  final GeoPoint? origin;

  /// Notified when a "Finding a responder" ping starts/ends, so the map can
  /// show a pulse animation at the origin point independent of wherever
  /// this card itself is displayed.
  final ValueChanged<bool>? onPingActiveChanged;

  /// The accepted responder's position and road route, for the map to draw
  /// — null when there's no responder sharing a position (or no ping).
  final ValueChanged<ResponderTrack?>? onResponderTrack;

  /// Tapping a category under "Go to Help" — routing to the nearest
  /// facility needs the full facility list and the map's route renderer,
  /// neither of which this card has, so that's handled by the caller.
  final ValueChanged<FacilityCategory>? onGoToHelp;

  /// Opens straight into "Finding a responder…" for this category — used by
  /// Go to Help's "Send SOS instead" handoff, which already knows which
  /// category the user picked in its own "Who do you need?" confirmation
  /// and shouldn't make them pick again from this sheet's choose-option view.
  final FacilityCategory? initialPingCategory;

  @override
  ConsumerState<GetHelpSheet> createState() => _GetHelpSheetState();
}

class _GetHelpSheetState extends ConsumerState<GetHelpSheet> {
  _HelpMode? _mode;

  _HelpCategory? _pingCategory;
  bool _pingCardExpanded = true;
  String? _address;
  bool _addressLoading = false;
  String? _addressError;
  bool _editingAddress = false;
  final _addressController = TextEditingController();

  AudioRecorder? _recorder;
  bool _isRecording = false;
  bool _voiceSent = false;
  bool _voiceUploading = false;

  /// The responder's road route to the ping, for the map and "Arrives in
  /// ~N min" — re-fetched, as on the web, only when they've moved more than
  /// 60 m since or changed travel mode.
  DirectionsRoute? _responderRoute;
  GeoPoint? _responderRouteFrom;
  TransportMode? _responderRouteMode;
  bool _fetchingResponderRoute = false;
  String? _agency;

  /// What the backend heard, shown under "✓ Voice description sent".
  String? _voiceTranscript;

  /// The web's inline pink line under the voice button.
  String? _voiceError;
  int _secondsLeft = _maxRecordingSeconds;
  Timer? _recordingTimer;

  /// The sole credential for this ping — set once `POST /api/ping` returns,
  /// used for every follow-up call (tracking, address correction, voice
  /// upload, cancel).
  String? _publicId;
  bool _pingCreating = false;
  String? _pingError;
  int _respondersAvailable = 0;
  PingStatus? _status;
  PingResponder? _responder;
  Timer? _pollTimer;

  static const _maxRecordingSeconds = 30;

  /// True until [_resumeStoredPing] has looked for a saved ping — the card
  /// renders nothing meanwhile, rather than flashing the choose-option view
  /// before swapping to an in-progress ping.
  bool _checkingStoredPing = false;

  /// Picks up a ping raised earlier — before an app restart, or before
  /// this card was closed — instead of offering to raise a new one. A ping
  /// that has since closed is still shown; polling reports its final state
  /// and clears it from storage.
  Future<void> _resumeStoredPing() async {
    ActivePing? loaded;
    try {
      loaded = await ref.read(activePingRepositoryProvider).load();
    } catch (_) {
      // Storage failing must never leave the card hidden mid-emergency —
      // fall through to the normal choose-option view.
    }
    final stored = loaded;
    if (!mounted) return;
    final category = stored?.agency.facilityCategory._helpCategory;
    if (stored == null || category == null) {
      setState(() => _checkingStoredPing = false);
      return;
    }
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          AnalyticsEvents.pingResumed,
          parameters: {'agency': stored.agency.name},
        );
    setState(() {
      _checkingStoredPing = false;
      _pingCategory = category;
      _publicId = stored.publicId;
      _respondersAvailable = stored.respondersAvailable;
      _addressLoading = true;
    });
    widget.onPingActiveChanged?.call(true);
    unawaited(_loadAddress(stored.origin));
    _startPolling();
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPingCategory?._helpCategory;
    if (initial == null) {
      _checkingStoredPing = true;
      unawaited(_resumeStoredPing());
      return;
    }
    _pingCategory = initial;
    _addressLoading = widget.origin != null;
    _pingCreating = widget.origin != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _beginPing(initial, widget.origin);
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recorder?.dispose();
    _pollTimer?.cancel();
    _addressController.dispose();
    if (_pingCategory != null) widget.onPingActiveChanged?.call(false);
    widget.onResponderTrack?.call(null);
    super.dispose();
  }

  void _startPing(_HelpCategory category) {
    setState(() {
      _pingCategory = category;
      _pingCardExpanded = true;
      _address = null;
      _addressError = null;
      _addressLoading = widget.origin != null;
      _editingAddress = false;
      _publicId = null;
      _pingCreating = widget.origin != null;
      _pingError = null;
      _respondersAvailable = 0;
      _status = null;
      _responder = null;
      _voiceSent = false;
      _clearResponderRoute();
    });
    _beginPing(category, widget.origin);
  }

  void _beginPing(_HelpCategory category, GeoPoint? origin) {
    widget.onPingActiveChanged?.call(true);
    if (origin == null) {
      setState(() {
        _addressError = 'Location unavailable';
        _pingError = 'Location unavailable';
        _pingCreating = false;
      });
      return;
    }
    unawaited(_loadAddress(origin));
    unawaited(_createPing(category, origin));
  }

  Future<void> _loadAddress(GeoPoint origin) async {
    try {
      final address = await ref
          .read(geocodingServiceProvider)
          .reverseGeocode(origin);
      if (!mounted) return;
      setState(() {
        _address = address;
        _addressLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addressError = 'Could not determine your address';
        _addressLoading = false;
      });
    }
  }

  /// Raises the real ping. A dropped pin was placed deliberately, so it's
  /// treated as a high-confidence point with a small nominal accuracy;
  /// "Your Location" instead takes a fresh GPS fix here (rather than
  /// trusting whatever [widget.origin] was last set to) so the accuracy
  /// value sent is real, not stale — `POST /api/ping` treats accuracy as
  /// meaningful, not decorative.
  Future<void> _createPing(_HelpCategory category, GeoPoint origin) async {
    var point = origin;
    var accuracy = 5.0;
    if (!widget.isPinnedLocation) {
      final location = await ref
          .read(locationRepositoryProvider)
          .currentPosition();
      if (location.position != null) {
        point = location.position!;
        accuracy = location.accuracy ?? 50;
      } else {
        accuracy = 50;
      }
    }
    if (!mounted) return;

    final profile = ref.read(emergencyProfileViewModelProvider).value;
    final result = await ref
        .read(pingServiceProvider)
        .raisePing(
          agency: category.pingAgency,
          point: point,
          accuracy: accuracy,
          medicalProfile: _formatMedicalProfile(profile),
        );
    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              AnalyticsEvents.pingCreated,
              parameters: {'agency': category.pingAgency.name},
            );
        setState(() {
          _publicId = value.publicId;
          _respondersAvailable = value.respondersAvailable;
          _pingCreating = false;
        });
        // Survives an app restart — see [ActivePingRepository].
        unawaited(
          ref
              .read(activePingRepositoryProvider)
              .save(
                ActivePing(
                  publicId: value.publicId,
                  agency: category.pingAgency,
                  origin: point,
                  isPinned: widget.isPinnedLocation,
                  respondersAvailable: value.respondersAvailable,
                ),
              ),
        );
        _startPolling();
      case Err(:final failure):
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              AnalyticsEvents.pingFailed,
              parameters: {
                'agency': category.pingAgency.name,
                'failure': '${failure.runtimeType}',
              },
            );
        setState(() {
          _pingError = failure.userMessage;
          _pingCreating = false;
        });
    }
  }

  /// Blood group / conditions / allergies only — [EmergencyProfile]'s name
  /// and next-of-kin fields aren't part of what responders need in the
  /// field. Null when the user never filled one in, so `medical_profile`
  /// is simply omitted from the request.
  String? _formatMedicalProfile(EmergencyProfile? profile) {
    if (profile == null || profile.isEmpty) return null;
    final parts = [
      if (profile.bloodGroup.isNotEmpty) 'Blood group: ${profile.bloodGroup}',
      if (profile.conditions.isNotEmpty) 'Conditions: ${profile.conditions}',
      if (profile.allergies.isNotEmpty) 'Allergies: ${profile.allergies}',
    ];
    return parts.isEmpty ? null : parts.join('. ');
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    unawaited(_poll());
  }

  Future<void> _poll() async {
    final publicId = _publicId;
    if (publicId == null) return;
    final result = await ref.read(pingServiceProvider).trackPing(publicId);
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        setState(() {
          _status = value.incident.status;
          _responder = value.responder;
          _agency = value.incident.agency;
        });
        unawaited(_trackResponder(value));
        if (value.incident.status.isClosed) {
          _pollTimer?.cancel();
          _pollTimer = null;
          unawaited(ref.read(activePingRepositoryProvider).clear());
        }
      case Err():
        // Transient — keep polling, the next tick may succeed.
        break;
    }
  }

  void _clearResponderRoute() {
    _responderRoute = null;
    _responderRouteFrom = null;
    _responderRouteMode = null;
  }

  /// Hands the map the responder's position and road route, as the web
  /// does on every status poll.
  Future<void> _trackResponder(PingTrackingInfo info) async {
    final responder = info.responder;
    final position = responder?.lastPoint;
    if (responder == null ||
        position == null ||
        info.incident.status.isClosed) {
      widget.onResponderTrack?.call(null);
      return;
    }
    final mode = TransportMode.values.firstWhere(
      (mode) => mode.backendMode == info.incident.responderMode,
      orElse: () => TransportMode.driving,
    );
    final from = _responderRouteFrom;
    final stale =
        mode != _responderRouteMode ||
        from == null ||
        haversineMeters(from, position) > 60;
    if (stale && !_fetchingResponderRoute) {
      _fetchingResponderRoute = true;
      final result = await ref
          .read(accessAnalysisServiceProvider)
          .fetchRoute(
            origin: position,
            destination: info.incident.userPoint,
            mode: mode,
          );
      _fetchingResponderRoute = false;
      if (!mounted) return;
      if (result case Ok(:final value)) {
        setState(() {
          _responderRoute = value;
          _responderRouteFrom = position;
          _responderRouteMode = mode;
        });
      }
    }
    widget.onResponderTrack?.call(
      ResponderTrack(
        position: position,
        name: responder.fullName,
        user: info.incident.userPoint,
        accuracyMeters: responder.lastAccuracy,
        route: _responderRoute?.points,
      ),
    );
  }

  void _startEditingAddress() {
    _addressController.text = _address ?? '';
    setState(() => _editingAddress = true);
  }

  /// Sends the user's own corrected address — geocoding in Lagos is
  /// unreliable, and the person standing there knows better.
  Future<void> _sendAddressCorrection() async {
    final corrected = _addressController.text.trim();
    if (corrected.isEmpty) return;
    setState(() {
      _address = corrected;
      _editingAddress = false;
    });
    final publicId = _publicId;
    if (publicId == null) return;
    final result = await ref
        .read(pingServiceProvider)
        .correctAddress(publicId, corrected);
    if (!mounted) return;
    if (result case Err(:final failure)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.userMessage)));
      }
    }
  }

  void _cancelAddressEdit() => setState(() => _editingAddress = false);

  void _cancelPing() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (_isRecording) unawaited(_recorder?.stop());
    _pollTimer?.cancel();
    _pollTimer = null;
    final publicId = _publicId;
    widget.onPingActiveChanged?.call(false);
    widget.onResponderTrack?.call(null);
    setState(() {
      _pingCategory = null;
      _mode = null;
      _isRecording = false;
      _voiceSent = false;
      _address = null;
      _addressError = null;
      _editingAddress = false;
      _publicId = null;
      _pingCreating = false;
      _pingError = null;
      _respondersAvailable = 0;
      _status = null;
      _responder = null;
      _clearResponderRoute();
    });
    if (publicId != null) {
      ref
          .read(analyticsServiceProvider)
          .logEvent(AnalyticsEvents.pingCancelled);
      unawaited(ref.read(pingServiceProvider).cancelPing(publicId));
      unawaited(ref.read(activePingRepositoryProvider).clear());
    }
  }

  Future<void> _toggleRecording() =>
      _isRecording ? _stopRecording() : _startRecording();

  Future<void> _startRecording() async {
    final recorder = _recorder ??= AudioRecorder();
    setState(() => _voiceError = null);
    if (!await recorder.hasPermission()) {
      if (mounted) {
        setState(() => _voiceError = 'Microphone permission denied.');
      }
      return;
    }
    final path =
        '${Directory.systemTemp.path}/ping_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await recorder.start(const RecordConfig(), path: path);
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _voiceSent = false;
      _secondsLeft = _maxRecordingSeconds;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        unawaited(_stopRecording());
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  /// Stops the recorder and uploads it — `POST /api/ping/{id}/voice`, max
  /// 30s, rate-limited 10/min. Deletes the local file either way; nothing
  /// keeps it around once it's sent (or once there's nowhere to send it).
  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final seconds = _maxRecordingSeconds - _secondsLeft;
    final path = await _recorder?.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (path == null) return;

    final publicId = _publicId;
    try {
      if (publicId == null) return;
      setState(() => _voiceUploading = true);
      final bytes = await File(path).readAsBytes();
      final result = await ref
          .read(pingServiceProvider)
          .uploadVoice(
            publicId,
            bytes: bytes,
            filename: path.split(Platform.pathSeparator).last,
            seconds: seconds > 0 ? seconds : null,
          );
      if (!mounted) return;
      switch (result) {
        case Ok(:final value):
          ref
              .read(analyticsServiceProvider)
              .logEvent(AnalyticsEvents.pingVoiceNoteSent);
          setState(() {
            _voiceUploading = false;
            _voiceSent = true;
            _voiceTranscript = value.transcript;
          });
        case Err(:final failure):
          setState(() {
            _voiceUploading = false;
            _voiceError = switch (failure) {
              NetworkFailure() ||
              TimeoutFailure() => 'Network error sending recording',
              _ => failure.userMessage,
            };
          });
      }
    } finally {
      try {
        await File(path).delete();
      } catch (_) {
        // Leftover temp file is harmless either way.
      }
    }
  }

  Future<void> _call112() async {
    ref
        .read(analyticsServiceProvider)
        .logEvent(AnalyticsEvents.call112, parameters: {'source': 'get_help'});
    final uri = Uri(scheme: 'tel', path: '112');
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start a call.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start a call.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingStoredPing) return const SizedBox.shrink();
    final isPinging = _pingCategory != null;
    return Material(
      color: context.palette.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: 8,
      shadowColor: Colors.black26,
      child: Container(
        decoration: isPinging
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: context.palette.danger, width: 1.5),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
          child: isPinging
              ? _buildPingPendingView(context)
              : _buildChooseOptionView(context),
        ),
      ),
    );
  }

  Widget _buildChooseOptionView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '🚨 Get Help Fast',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            InkWell(
              onTap: widget.onDismiss ?? () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(AppRadii.full),
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: context.palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Choose one option',
          style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: _OptionChip(
                icon: Icons.sensors,
                label: 'Ping for Help',
                color: context.palette.danger,
                selected: _mode == _HelpMode.ping,
                onTap: () => setState(() => _mode = _HelpMode.ping),
              ),
            ),
            Expanded(
              child: _OptionChip(
                icon: Icons.directions_car,
                label: 'Go to Help',
                color: context.palette.primary,
                selected: _mode == _HelpMode.goToHelp,
                onTap: () => setState(() => _mode = _HelpMode.goToHelp),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _mode == null
                ? 'Pick an option above first'
                : 'Then choose help type',
            style: TextStyle(
              fontSize: 12,
              color: _mode == null
                  ? context.palette.textSecondary
                  : context.palette.danger,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _HelpCategory.values.map((category) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    onTap: _mode == null
                        ? null
                        : _mode == _HelpMode.ping
                        ? () => _startPing(category)
                        : () => widget.onGoToHelp?.call(
                            category.facilityCategory,
                          ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.palette.backgroundCanvas,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        // IntrinsicHeight + stretch (above) sizes every
                        // tile to the tallest one instead of a hardcoded
                        // height — "Road Safety" wrapping to two lines
                        // while the rest stayed on one is what made that
                        // tile look mismatched (and a fixed height too
                        // short for the wrapped case overflowed).
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              category.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              category.label,
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
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.isPinnedLocation) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: context.palette.danger,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This is a pinned location, not your GPS position. A ping sends responders to this pin.',
                  style: TextStyle(fontSize: 10, color: context.palette.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text(
          '((•)) Ping notifies responders and shares locations both ways.\n'
          '🚗 Go to Help routes you by car to the nearest facility.',
          style: TextStyle(color: context.palette.textSecondary, fontSize: 10),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: 'My emergency profile',
            icon: Icons.healing,
            variant: AppButtonVariant.secondary,
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const EmergencyProfileSheet(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            icon: Icons.arrow_back,
            label: 'Back to pin',
            variant: AppButtonVariant.secondary,
            onPressed:
                widget.onBack ??
                widget.onDismiss ??
                () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }

  String _statusHeadline(_HelpCategory category) {
    if (_pingError != null) return 'Could not send ping';
    if (_pingCreating) return 'Sending your ping…';
    if (_respondersAvailable == 0) return 'No responders available';
    return switch (_status) {
      null || PingStatus.pending => 'Finding a responder…',
      PingStatus.accepted => 'A responder is on the way',
      PingStatus.enRoute => 'Responder en route',
      PingStatus.arrived => 'Responder has arrived',
      PingStatus.resolved => 'Marked resolved',
      PingStatus.cancelled => 'Ping cancelled',
      PingStatus.expired => 'Ping expired',
    };
  }

  String _statusBody(_HelpCategory category) {
    if (_pingError != null) return _pingError!;
    if (_pingCreating) return 'Reaching out to nearby ${category.agencyLabel}…';
    if (_respondersAvailable == 0) {
      return 'Nobody is on duty for ${category.agencyLabel} right now. '
          'Please call 112 immediately.';
    }
    switch (_status) {
      case PingStatus.resolved:
        return 'This ping has been marked resolved.';
      case PingStatus.expired:
        return 'This ping expired with no response. Please call 112.';
      case PingStatus.cancelled:
        return 'This ping was cancelled.';
      default:
        break;
    }
    // An accepted responder gets the web's own block instead.
    if (_responder != null) return '';
    return 'Your location has been sent to nearby ${category.agencyLabel} on duty. '
        'If nobody answers shortly, call 112.';
  }

  /// The web's responder block: name, agency and station, phone, the
  /// "Arrives in" box from their road route, and whether their position is
  /// being shared.
  Widget _buildResponder(PingResponder responder) {
    final muted = TextStyle(
      fontSize: 12,
      height: 1.6,
      color: context.palette.textSecondary,
    );
    final route = _responderRoute;
    final phone = responder.phone;
    final station = responder.stationName;
    final kilometres = route == null
        ? ''
        : (route.distanceMeters / 1000).toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            responder.fullName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          Text([?_agency, ?station].join(' · '), style: muted),
          if (phone != null)
            InkWell(
              onTap: () => launchUrl(Uri(scheme: 'tel', path: phone)),
              child: Text.rich(
                TextSpan(
                  text: '📞 ',
                  style: muted,
                  children: [
                    TextSpan(
                      text: phone,
                      style: TextStyle(color: context.palette.primary),
                    ),
                  ],
                ),
              ),
            ),
          if (route != null && responder.lastPoint != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: context.palette.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: context.palette.accentGreen),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Arrives in ~${_formatEta(route.durationSeconds)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.palette.accentGreen,
                      ),
                      children: [
                        TextSpan(
                          text: ' · $kilometres km by road',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!route.hasLiveTraffic)
                    Text(
                      'Estimated without live traffic',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.palette.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          if (responder.lastPoint == null)
            Text('Position not being shared right now', style: muted)
          else
            Text(
              '● Live position shared',
              style: muted.copyWith(color: context.palette.accentGreen),
            ),
        ],
      ),
    );
  }

  /// The web's duration format: "7 min", "1 hr", "1 hr 20 min".
  static String _formatEta(double seconds) {
    final minutes = (seconds / 60).round().clamp(1, 1 << 30);
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours hr' : '$hours hr $rest min';
  }

  Widget _buildPingPendingView(BuildContext context) {
    final category = _pingCategory!;
    if (!_pingCardExpanded) return _buildPingMinimizedView(category);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _statusHeadline(category),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.palette.danger,
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _pingCardExpanded = false),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.palette.backgroundCanvas,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: context.palette.border),
                ),
                child: Icon(
                  Icons.expand_more,
                  size: 18,
                  color: context.palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (_statusBody(category) case final body when body.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(fontSize: 13, color: context.palette.textPrimary),
          ),
        ],
        if (_responder case final responder?) _buildResponder(responder),
        if (_pingError != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () {
                setState(() {
                  _pingError = null;
                  _pingCreating = widget.origin != null;
                });
                final origin = widget.origin;
                if (origin != null) unawaited(_createPing(category, origin));
              },
            ),
          ),
        ],
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 12,
              color: context.palette.textSecondary,
            ),
            children: [
              const TextSpan(text: 'Address sent: '),
              TextSpan(
                text: _addressLoading
                    ? 'Working out your address…'
                    : (_address ?? _addressError ?? ''),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (_editingAddress) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            autofocus: true,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: AppButton(
                  label: 'Send correction',
                  onPressed: _sendAddressCorrection,
                ),
              ),
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.secondary,
                  onPressed: _cancelAddressEdit,
                ),
              ),
            ],
          ),
        ] else
          InkWell(
            onTap: _addressLoading ? null : _startEditingAddress,
            child: Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Not right? Fix it',
                style: TextStyle(
                  fontSize: 12,
                  color: context.palette.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (_voiceSent && !_isRecording) ...[
          Text(
            '✓ Voice description sent',
            style: TextStyle(
              fontSize: 12,
              color: context.palette.success,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_voiceTranscript case final transcript?
              when transcript.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              '“${transcript.trim()}”',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: context.palette.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 2),
          // Back to the Add button, as on the web — not straight into a
          // new recording.
          InkWell(
            onTap: () => setState(() {
              _voiceSent = false;
              _voiceTranscript = null;
            }),
            child: Text(
              'Record again',
              style: TextStyle(
                fontSize: 12,
                color: context.palette.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ] else if (_voiceUploading)
          Text(
            'Sending recording…',
            style: TextStyle(
              fontSize: 12,
              color: context.palette.textSecondary,
            ),
          )
        else ...[
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: _isRecording
                  ? '■ Stop (${_secondsLeft}s)'
                  : '🎤 Add voice description',
              variant: _isRecording
                  ? AppButtonVariant.neutral
                  : AppButtonVariant.primary,
              onPressed: (_isRecording || _publicId != null)
                  ? _toggleRecording
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isRecording
                ? '● Recording — say where you are and what is wrong'
                : 'Responders will hear this and read a transcript.',
            style: TextStyle(
              fontSize: 11,
              color: _isRecording
                  ? context.palette.danger
                  : context.palette.textSecondary,
              fontWeight: _isRecording ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
        if (_voiceError case final error?) ...[
          const SizedBox(height: 4),
          Text(
            error,
            style: TextStyle(fontSize: 11, color: context.palette.danger),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: AppButton(
                label: 'Call 112',
                variant: AppButtonVariant.danger,
                onPressed: _call112,
              ),
            ),
            Expanded(
              child: AppButton(
                label: 'Cancel ping',
                variant: AppButtonVariant.secondary,
                onPressed: _cancelPing,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPingMinimizedView(_HelpCategory category) {
    return InkWell(
      onTap: () => setState(() => _pingCardExpanded = true),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusHeadline(category),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.palette.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // The web: who's coming, once someone has accepted.
                  _responder?.fullName ?? 'Tap for details',
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
            onTap: _call112,
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.palette.danger,
              ),
              child: const Icon(Icons.call, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => _pingCardExpanded = true),
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.palette.backgroundCanvas,
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

/// The "Ping for Help" / "Go to Help" toggle chips — outlined in [color]
/// when idle, filled solid with white content once picked, so choosing one
/// visibly commits to it before the help-type grid below unlocks.
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contentColor = selected ? Colors.white : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            Icon(icon, size: 18, color: contentColor),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: contentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
