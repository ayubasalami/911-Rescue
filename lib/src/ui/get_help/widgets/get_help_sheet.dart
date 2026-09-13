import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/geo_point.dart';
import '../../../data/services/geocoding_service.dart';
import '../../core/widgets/app_button.dart';
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
}

class GetHelpSheet extends ConsumerStatefulWidget {
  const GetHelpSheet({
    super.key,
    this.onDismiss,
    this.onBack,
    this.isPinnedLocation = false,
    this.origin,
    this.onPingActiveChanged,
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

  AudioRecorder? _recorder;
  bool _isRecording = false;
  bool _voiceSent = false;
  int _secondsLeft = _maxRecordingSeconds;
  Timer? _recordingTimer;

  static const _maxRecordingSeconds = 30;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recorder?.dispose();
    if (_pingCategory != null) widget.onPingActiveChanged?.call(false);
    super.dispose();
  }

  void _startPing(_HelpCategory category) {
    setState(() {
      _pingCategory = category;
      _pingCardExpanded = true;
      _address = null;
      _addressError = null;
      _addressLoading = widget.origin != null;
    });
    widget.onPingActiveChanged?.call(true);
    final origin = widget.origin;
    if (origin == null) {
      setState(() => _addressError = 'Location unavailable');
      return;
    }
    unawaited(_loadAddress(origin));
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

  void _cancelPing() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (_isRecording) unawaited(_recorder?.stop());
    widget.onPingActiveChanged?.call(false);
    setState(() {
      _pingCategory = null;
      _mode = null;
      _isRecording = false;
      _voiceSent = false;
      _address = null;
      _addressError = null;
    });
  }

  Future<void> _toggleRecording() =>
      _isRecording ? _stopRecording() : _startRecording();

  Future<void> _startRecording() async {
    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) return;
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

  /// Stops the recorder and discards the file — there's no backend for this
  /// mocked flow to send it to, so only the "sent" UI state matters.
  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final path = await _recorder?.stop();
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {
        // Nothing to send this to anyway — a leftover temp file is harmless.
      }
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _voiceSent = true;
    });
  }

  Future<void> _call112() async {
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
    final isPinging = _pingCategory != null;
    return Material(
      color: AppColors.backgroundSurface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: 8,
      shadowColor: Colors.black26,
      child: Container(
        decoration: isPinging
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.danger, width: 1.5),
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
        const SizedBox(height: 2),
        const Text(
          'Choose one option',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: _OptionChip(
                icon: Icons.sensors,
                label: 'Ping for Help',
                color: AppColors.danger,
                selected: _mode == _HelpMode.ping,
                onTap: () => setState(() => _mode = _HelpMode.ping),
              ),
            ),
            Expanded(
              child: _OptionChip(
                icon: Icons.directions_car,
                label: 'Go to Help',
                color: AppColors.primary,
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
              color: _mode == null ? AppColors.textSecondary : AppColors.danger,
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
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${category.label} requested (demo)',
                              ),
                            ),
                          ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundCanvas,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.border),
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
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppColors.danger,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This is a pinned location, not your GPS position. A ping sends responders to this pin.',
                  style: TextStyle(fontSize: 10, color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          '((•)) Ping notifies responders and shares locations both ways.\n'
          '🚗 Go to Help routes you by car to the nearest facility.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
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

  Widget _buildPingPendingView(BuildContext context) {
    final category = _pingCategory!;
    if (!_pingCardExpanded) return _buildPingMinimizedView(category);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Finding a responder…',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _pingCardExpanded = false),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCanvas,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.expand_more,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Your location has been sent to nearby ${category.agencyLabel} on duty. '
          'If nobody answers shortly, call 112.',
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            children: [
              const TextSpan(text: 'Address sent: '),
              TextSpan(
                text: _addressLoading
                    ? 'Working out your address…'
                    : (_address ?? _addressError ?? ''),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Editing the address is coming soon.'),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Not right? Fix it',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_voiceSent && !_isRecording) ...[
          const Text(
            '✓ Voice description sent',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: _toggleRecording,
            child: const Text(
              'Record again',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: _isRecording
                  ? 'Stop (${_secondsLeft}s)'
                  : 'Add voice description',
              icon: _isRecording ? Icons.stop : Icons.mic,
              variant: _isRecording
                  ? AppButtonVariant.neutral
                  : AppButtonVariant.primary,
              onPressed: _toggleRecording,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isRecording
                ? '• Recording — say where you are and what is wrong'
                : 'Responders will hear this and read a transcript.',
            style: TextStyle(
              fontSize: 11,
              color: _isRecording ? AppColors.danger : AppColors.textSecondary,
              fontWeight: _isRecording ? FontWeight.w600 : FontWeight.normal,
            ),
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
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finding a responder…',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tap for details',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.danger,
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
                color: AppColors.backgroundCanvas,
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
