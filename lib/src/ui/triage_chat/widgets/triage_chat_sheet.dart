import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../core/widgets/app_filter_chip.dart';

const _quickReplies = [
  'Chest pain',
  'Difficulty breathing',
  'Robbery in progress',
  'Fire / smoke',
  'Road accident',
  'Child with fever',
];

/// The Triage chatbot screen. UI only for now — quick replies fill the
/// input, and sending shows a placeholder response rather than calling a
/// real triage backend.
class TriageChatSheet extends StatefulWidget {
  const TriageChatSheet({super.key});

  @override
  State<TriageChatSheet> createState() => _TriageChatSheetState();
}

class _TriageChatSheetState extends State<TriageChatSheet> {
  final _controller = TextEditingController();
  bool _hasText = false;

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
    super.dispose();
  }

  void _send() {
    if (!_hasText) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connecting you to a responder is coming soon.')),
    );
    _controller.clear();
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
                child: Text('911 Rescue Triage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              InkWell(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close)),
            ],
          ),
          const Divider(height: 24),
          Row(
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
                  child: const Text(
                    "Hi! 👋 Briefly describe what's happening — medical, safety, fire, or "
                    "road-related — and I'll connect you to the right responder on the map.",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reply in _quickReplies)
                AppFilterChip(label: reply, selected: false, onTap: () => _controller.text = reply),
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
                  decoration: InputDecoration(
                    hintText: 'Describe your symptoms...',
                    filled: true,
                    fillColor: AppColors.backgroundCanvas,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: _hasText ? AppColors.primary : AppColors.border,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _send,
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
}
