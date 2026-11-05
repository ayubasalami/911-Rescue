import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Height of the sheet's collapsed peek: the handle and a little of the
/// tab's heading.
const homeSheetPeekHeight = 64.0;

/// Fraction of the map area the sheet rests at when partly open.
const homeSheetHalfSize = 0.45;

/// The Google Maps-style panel holding every tab's content, over a map that
/// stays usable: collapsed, partly open or nearly full height.
class HomeSheet extends StatelessWidget {
  const HomeSheet({
    super.key,
    required this.controller,
    required this.topInset,
    required this.onHeightChanged,
    required this.builder,
  });

  final DraggableScrollableController controller;

  /// Status bar height — the fully open sheet stops short of it.
  final double topInset;

  /// The sheet's height in pixels, as it moves.
  final ValueChanged<double> onHeightChanged;

  final Widget Function(BuildContext context, ScrollController scrollController)
  builder;

  void _dragHandle(DragUpdateDetails details, double available) {
    if (!controller.isAttached) return;
    controller.jumpTo(controller.size - details.primaryDelta! / available);
  }

  void _settle(double min, double max) {
    if (!controller.isAttached) return;
    final size = controller.size;
    final nearest = [
      min,
      homeSheetHalfSize,
      max,
    ].reduce((a, b) => (a - size).abs() <= (b - size).abs() ? a : b);
    controller.animateTo(
      nearest,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight;
        final min = (homeSheetPeekHeight / available).clamp(0.05, 0.4);
        final max = (1 - (topInset + 8) / available).clamp(0.5, 1.0);
        // The sheet only reports its height as it moves, so report it after
        // layout too: on first show, and when the keyboard resizes the map.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.isAttached) onHeightChanged(controller.pixels);
        });
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            onHeightChanged(notification.extent * available);
            return false;
          },
          child: DraggableScrollableSheet(
            controller: controller,
            // Collapsed, so the SOS button under it shows on opening.
            initialChildSize: min,
            minChildSize: min,
            maxChildSize: max,
            expand: false,
            snap: true,
            snapSizes: const [homeSheetHalfSize],
            builder: (context, scrollController) => Material(
              color: context.palette.backgroundSurface,
              elevation: 8,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadii.lg),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Drags the sheet from any tab, including Chat, whose
                  // messages scroll on their own.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) =>
                        _dragHandle(details, available),
                    onVerticalDragEnd: (_) => _settle(min, max),
                    child: SizedBox(
                      width: double.infinity,
                      height: 24,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.palette.border,
                            borderRadius: BorderRadius.circular(AppRadii.full),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: builder(context, scrollController)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
