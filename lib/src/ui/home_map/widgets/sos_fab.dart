import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The red 🚨 SOS button, with the web platform's `fab-attention` pulse:
/// a 2.6s loop where a pink ring sits hidden at the button's edge, then
/// (82%→90%) expands 12px out while fading, and eases back (90%→100%).
class SosFab extends StatefulWidget {
  const SosFab({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<SosFab> createState() => _SosFabState();
}

class _SosFabState extends State<SosFab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// Only loops while the system allows animation — a repeating controller
  /// keeps scheduling frames even when nothing draws it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  static const _ringColor = Color(0xFFD9004C);
  static const _maxSpread = 12.0;
  static const _maxAlpha = 0.55;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The ring's (spread, alpha) at loop position [t], following the web's
  /// keyframes. CSS eases each keyframe segment separately, so this does
  /// too.
  (double, double) _ringAt(double t) {
    if (t < 0.82) return (0, _maxAlpha);
    if (t < 0.90) {
      final p = Curves.easeInOut.transform((t - 0.82) / 0.08);
      return (_maxSpread * p, _maxAlpha * (1 - p));
    }
    final p = Curves.easeInOut.transform((t - 0.90) / 0.10);
    return (_maxSpread * (1 - p), _maxAlpha * p);
  }

  @override
  Widget build(BuildContext context) {
    final button = FloatingActionButton(
      shape: const CircleBorder(),
      backgroundColor: AppColors.danger,
      onPressed: widget.onPressed,
      child: const Text('🚨', style: TextStyle(fontSize: 26)),
    );
    if (MediaQuery.disableAnimationsOf(context)) return button;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final (spread, alpha) = _ringAt(_controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _ringColor.withValues(alpha: alpha),
                spreadRadius: spread,
              ),
            ],
          ),
          child: child,
        );
      },
      child: button,
    );
  }
}
