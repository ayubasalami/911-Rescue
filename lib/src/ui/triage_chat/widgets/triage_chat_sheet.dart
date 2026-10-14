import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ping.dart';
import '../../../data/models/triage.dart';
import '../../../data/services/triage_service.dart';
import '../../core/widgets/app_filter_chip.dart';

const _quickReplies = [
  'Chest pain',
  'Difficulty breathing',
  'Robbery in progress',
  'Fire / smoke',
  'Road accident',
  'Child with fever',
];

sealed class _ChatEntry {
  const _ChatEntry();
}

class _UserEntry extends _ChatEntry {
  const _UserEntry(this.text);
  final String text;
}

class _LoadingEntry extends _ChatEntry {
  const _LoadingEntry();
}

class _ErrorEntry extends _ChatEntry {
  const _ErrorEntry(this.message);
  final String message;
}

class _AssessmentEntry extends _ChatEntry {
  const _AssessmentEntry(this.assessment);
  final TriageAssessment assessment;
}

/// The Triage chatbot — sends what the user types to
/// `POST /api/triage_symptoms` and turns the result into actions, the way
/// the web does: "Call 112 Now" for an emergency, a routing button for the
/// agency ("Show nearest …" for an emergency, "Navigate to …" otherwise)
/// plus "Also: …" for a secondary agency, and nothing but the message for
/// a sensitive topic. Picking the facility and routing to it is the
/// caller's job ([onNavigateTo]) — this widget has no map context.
class TriageChatSheet extends ConsumerStatefulWidget {
  const TriageChatSheet({
    super.key,
    required this.onNavigateTo,
    required this.onCall112,
  });

  final ValueChanged<TriageNavigation> onNavigateTo;
  final VoidCallback onCall112;

  @override
  ConsumerState<TriageChatSheet> createState() => _TriageChatSheetState();
}

class _TriageChatSheetState extends ConsumerState<TriageChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatEntry>[];
  bool _hasText = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _fillQuickReply(String reply) {
    _controller.text = reply;
    _controller.selection = TextSelection.collapsed(offset: reply.length);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _messages.add(_UserEntry(text));
      _messages.add(const _LoadingEntry());
      _sending = true;
    });
    _scrollToBottom();

    final result = await ref.read(triageServiceProvider).assessSymptoms(text);
    if (!mounted) return;
    setState(() {
      _messages.removeLast();
      _sending = false;
      switch (result) {
        case Ok(:final value):
          _messages.add(_AssessmentEntry(value));
        case Err(:final failure):
          _messages.add(_ErrorEntry(failure.userMessage));
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, color: AppColors.success, size: 10),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '911 Rescue Triage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(height: 24),
          // Flexible (not a fixed maxHeight) so this takes whatever room is
          // actually left in the dialog and scrolls internally instead of
          // overflowing — the dialog has less room once the keyboard is up,
          // which is exactly when a send is most likely to happen.
          Flexible(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _assistantBubble(
                    const Text(
                      "Hi! 👋 Briefly describe what's happening — medical, safety, "
                      "fire, or road-related — and I'll connect you to the right "
                      'responder on the map.',
                    ),
                  ),
                  for (final entry in _messages) _buildEntry(entry),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reply in _quickReplies)
                AppFilterChip(
                  label: reply,
                  selected: false,
                  onTap: () => _fillQuickReply(reply),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_sending,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Describe your symptoms...',
                    filled: true,
                    fillColor: AppColors.backgroundCanvas,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: (_hasText && !_sending)
                    ? AppColors.primary
                    : AppColors.border,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: (_hasText && !_sending) ? _send : null,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(_ChatEntry entry) => switch (entry) {
    _UserEntry() => _userBubble(entry.text),
    _LoadingEntry() => _loadingBubble(),
    _ErrorEntry() => _assistantBubble(
      Text(entry.message, style: const TextStyle(color: AppColors.danger)),
    ),
    _AssessmentEntry() => _assessmentBubble(entry.assessment),
  };

  /// Doesn't reuse [_assistantBubble] — that wraps its child in [Expanded],
  /// which is right for a text response but stretches a tiny spinner's
  /// container across the full width instead of hugging it.
  Widget _loadingBubble() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary,
          child: Text('🏥', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.backgroundCanvas,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ],
    ),
  );

  Widget _userBubble(String text) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    ),
  );

  /// [emergency] and [sensitive] are the web's `.bubble.ai.emergency` /
  /// `.sensitive` variants: a pink 🚨 avatar and pink-tinted bubble for an
  /// emergency, a faint blue tint for a sensitive topic.
  Widget _assistantBubble(
    Widget child, {
    bool emergency = false,
    bool sensitive = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: emergency ? AppColors.danger : AppColors.primary,
          child: Text(
            emergency ? '🚨' : '🏥',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: emergency
                  ? AppColors.danger.withValues(alpha: 0.1)
                  : sensitive
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : AppColors.backgroundCanvas,
              border: emergency ? Border.all(color: AppColors.danger) : null,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: child,
          ),
        ),
      ],
    ),
  );

  /// Mirrors the web's response bubble: the message, a dashed-off note when
  /// a secondary agency may also be needed, an "answered offline" note for
  /// the keyword classifier, "Call 112 Now" for an emergency, then the
  /// routing button(s). A sensitive topic gets the message only — no
  /// routing. An agency this app doesn't recognize hides its button rather
  /// than guessing where to send the user.
  Widget _assessmentBubble(TriageAssessment assessment) {
    final emergency = assessment.isEmergency;
    final secondary = assessment.secondaryAgency;
    final agency = assessment.agency;
    final actions = assessment.sensitive
        ? const <Widget>[]
        : <Widget>[
            if (agency != null)
              _routeAction(
                emergency
                    ? 'Show nearest ${agency.apiValue}'
                    : 'Navigate to ${agency.apiValue}',
                TriageNavigation(
                  category: agency.facilityCategory,
                  department: assessment.department,
                  isEmergency: emergency,
                ),
              ),
            if (secondary != null)
              _routeAction(
                'Also: ${secondary.apiValue}',
                TriageNavigation(
                  category: secondary.facilityCategory,
                  isEmergency: emergency,
                ),
              ),
          ];

    return _assistantBubble(
      emergency: emergency,
      sensitive: assessment.sensitive,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(assessment.message),
          if (secondary != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              'This may also need ${secondary.apiValue}.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (assessment.source == TriageSource.local) ...[
            const SizedBox(height: 6),
            const Text(
              'Answered offline — AI triage unavailable, so this is a simpler '
              'keyword match.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          if (emergency) ...[
            const SizedBox(height: 10),
            _actionButton(
              label: 'Call 112 Now',
              icon: Icons.call,
              color: AppColors.danger,
              onPressed: widget.onCall112,
            ),
          ],
          // Stacked, not side by side like the web's desktop row: at phone
          // width two buttons each wrap to three lines.
          for (final action in actions) ...[const SizedBox(height: 8), action],
        ],
      ),
    );
  }

  Widget _routeAction(String label, TriageNavigation navigation) =>
      _actionButton(
        label: label,
        icon: Icons.location_on_outlined,
        color: _webGreen,
        onPressed: () => widget.onNavigateTo(navigation),
      );

  /// The web's `.bubble-action`: full-width, 10px corners, bold 13px label.
  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

/// The web's `--accent-green`.
const _webGreen = Color(0xFF00AA55);
