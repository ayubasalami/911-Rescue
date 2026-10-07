import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/ping.dart';
import '../../../data/models/triage.dart';
import '../../../data/services/triage_service.dart';
import '../../core/widgets/app_button.dart';
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
/// `POST /api/triage_symptoms` and turns the result into an action: an
/// emergency gets a "Send Ping"/"Call 112" choice, a non-emergency gets
/// "Go to Help", and a sensitive topic gets support framing with no
/// facility routing at all. Routing itself (raising the ping, starting Go
/// to Help) is the caller's job — this widget has no map context of its
/// own, same division used by `GetHelpSheet`.
class TriageChatSheet extends ConsumerStatefulWidget {
  const TriageChatSheet({
    super.key,
    required this.onSendPing,
    required this.onGoToHelp,
    required this.onCall112,
  });

  final ValueChanged<FacilityCategory> onSendPing;
  final ValueChanged<FacilityCategory> onGoToHelp;
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

  Widget _assistantBubble(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary,
          child: Text('🏥', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundCanvas,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: child,
          ),
        ),
      ],
    ),
  );

  /// `sensitive: true` gets support framing and a 112 button only — never a
  /// facility routing button, per the API docs. Otherwise: the assessment
  /// text, an "offline classifier" note when [TriageAssessment.source] is
  /// [TriageSource.local], and either "Send Ping"/"Call 112" (emergency) or
  /// "Go to Help" (not), gated on recognizing [TriageAssessment.agency] at
  /// all — an unrecognized string hides the routing buttons rather than
  /// guessing where to send the user.
  Widget _assessmentBubble(TriageAssessment assessment) {
    if (assessment.sensitive) {
      return _assistantBubble(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(assessment.message),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Call 112',
                variant: AppButtonVariant.danger,
                onPressed: widget.onCall112,
              ),
            ),
          ],
        ),
      );
    }

    final agency = assessment.agency;
    return _assistantBubble(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (agency != null)
            Text(
              [
                agency.apiValue,
                if (assessment.department != null) assessment.department!,
                assessment.urgency,
              ].join(' · '),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          const SizedBox(height: 4),
          Text(assessment.message),
          if (assessment.source == TriageSource.local) ...[
            const SizedBox(height: 6),
            const Text(
              'Answered by the offline classifier — less precise than usual.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (agency != null) ...[
            const SizedBox(height: 10),
            Row(
              spacing: 8,
              children: assessment.isEmergency
                  ? [
                      Expanded(
                        child: AppButton(
                          label: 'Send Ping',
                          icon: Icons.sensors,
                          variant: AppButtonVariant.danger,
                          onPressed: () =>
                              widget.onSendPing(agency.facilityCategory),
                        ),
                      ),
                      Expanded(
                        child: AppButton(
                          label: 'Call 112',
                          variant: AppButtonVariant.secondary,
                          onPressed: widget.onCall112,
                        ),
                      ),
                    ]
                  : [
                      Expanded(
                        child: AppButton(
                          label: 'Go to Help',
                          icon: Icons.directions_car,
                          onPressed: () =>
                              widget.onGoToHelp(agency.facilityCategory),
                        ),
                      ),
                    ],
            ),
          ],
        ],
      ),
    );
  }
}
