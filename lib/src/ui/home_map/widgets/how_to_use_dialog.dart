import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';

/// The web's "How to Use This Map" tutorial — same four pages, wording and
/// Back / dots / Next controls. Also shown once, automatically, the first
/// time the map opens (see [showHowToUseIfFirstVisit]).
Future<void> showHowToUseDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierColor: const Color(0x73111827),
    builder: (_) => const HowToUseDialog(),
  );
  await _markSeen();
}

/// The web shows the tutorial on a first visit, once the map is ready, and
/// remembers it was seen (`tutorialSeen_v2`). Never throws — a storage
/// failure just means it may show again.
Future<void> showHowToUseIfFirstVisit(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seenKey) ?? false) return;
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  await showHowToUseDialog(context);
}

const _seenKey = 'tutorial_seen_v2';

Future<void> _markSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  } catch (_) {
    // Worst case the tutorial shows again next launch.
  }
}

class _TutorialPage {
  const _TutorialPage({
    required this.title,
    required this.intro,
    required this.items,
  });

  final String title;
  final String intro;
  final List<(String, String)> items;
}

const _pages = [
  _TutorialPage(
    title: 'Welcome to 911 Rescue',
    intro:
        'Find and reach emergency help across Lagos — hospitals, police, '
        'fire and road safety — in one map.',
    items: [
      (
        'Get help in two taps',
        'The card on your location is the fastest route to help. Choose '
            'Ping for Help or Go to Help, then the kind of help you need.',
      ),
      (
        'Ping for Help',
        'Alerts responders on duty and shares your location with them. You '
            'will see who accepts and watch them approach.',
      ),
      (
        'Go to Help',
        'Routes you to the nearest facility of the type you choose, by car '
            'unless you pick another mode.',
      ),
      (
        'Call 112 anytime',
        'The red button is always on screen. For a life-threatening '
            'emergency, call it.',
      ),
    ],
  ),
  _TutorialPage(
    title: 'Not sure who to call?',
    intro:
        'Describe what is happening and the assistant works out who should '
        'respond.',
    items: [
      (
        'Just describe it',
        '"Chest pain", "there\'s a fire", "road accident" — plain words are '
            'enough. It matches you to medical, police, fire or road safety.',
      ),
      (
        'It routes you automatically',
        'Once matched, the nearest suitable facility is found and a route '
            'drawn for you.',
      ),
      (
        'Emergencies go to real hospitals',
        'For an emergency it will not send you to a pharmacy or a '
            'laboratory, even if one is closer — those cannot admit a '
            'patient.',
      ),
    ],
  ),
  _TutorialPage(
    title: 'Getting there',
    intro: 'Once a route is drawn you can follow it live.',
    items: [
      (
        'Start to follow',
        'Press Start and the map tracks you, counting down the distance and '
            'warning you if you leave the route.',
      ),
      (
        'Change how you travel',
        'Car, Okada, Bike or Walk — the pills at the top redraw the route '
            'and update the time.',
      ),
      (
        'Voice directions',
        'Optional. Turn it on and you will hear the next turn as you '
            'approach it.',
      ),
      (
        'Send SOS instead',
        'If things change on the way, you can abandon the journey and call '
            'for responders from where you are.',
      ),
    ],
  ),
  _TutorialPage(
    title: 'Exploring the map',
    intro: 'Beyond emergencies, the map answers what is reachable from where.',
    items: [
      (
        'Tap to analyse',
        'Tap any point to see which facilities are reachable, grouped by how '
            'many minutes away they are.',
      ),
      (
        'Search and filter',
        'Search by name or address, or use the category pills to show only '
            'police, fire, health and so on.',
      ),
      (
        'Zoom in to see facilities',
        'At city-wide zoom individual facilities stay hidden to keep the map '
            'readable — zoom in to reveal them.',
      ),
      (
        'Your emergency profile',
        'Add blood group, conditions and allergies once, and they travel '
            'with any ping you send. Stored on your device only.',
      ),
    ],
  ),
];

/// The web's `--accent-green`.
const _webGreen = Color(0xFF00AA55);

class HowToUseDialog extends StatefulWidget {
  const HowToUseDialog({super.key});

  @override
  State<HowToUseDialog> createState() => _HowToUseDialogState();
}

class _HowToUseDialogState extends State<HowToUseDialog> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    final isFirst = _index == 0;
    final isLast = _index == _pages.length - 1;
    const muted = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13,
      height: 1.6,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 25, 26, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    page.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _webGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Divider(height: 1),
                  const SizedBox(height: 15),
                  Text(
                    page.intro,
                    style: muted.copyWith(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 15),
                  for (final (label, text) in page.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ', style: muted),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: muted,
                                children: [
                                  TextSpan(
                                    text: '$label: ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  TextSpan(text: text),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      SizedBox(
                        width: 84,
                        child: isFirst
                            ? null
                            : _TutorialButton(
                                label: '⬅ Back',
                                onPressed: () => setState(() => _index--),
                              ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 6,
                          children: [
                            for (var i = 0; i < _pages.length; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: i == _index ? 16 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  // Darker than the web's border-colour dots,
                                  // which almost vanish on a white dialog.
                                  color: i == _index
                                      ? AppColors.primary
                                      : AppColors.textSecondary.withValues(
                                          alpha: 0.35,
                                        ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 84,
                        child: _TutorialButton(
                          label: isLast ? 'Close' : 'Next ➔',
                          primary: true,
                          onPressed: isLast
                              ? () => Navigator.of(context).pop()
                              : () => setState(() => _index++),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The web's `.btn-tut`; [primary] is its blue-to-green gradient variant.
class _TutorialButton extends StatelessWidget {
  const _TutorialButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(6);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: primary
            ? const LinearGradient(colors: [AppColors.primary, _webGreen])
            : null,
        color: primary ? null : AppColors.backgroundCanvas,
        border: primary ? null : Border.all(color: AppColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: primary ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
