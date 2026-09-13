import 'package:flutter/material.dart';

import '../../../data/models/facility.dart';

/// Draws [category]'s exact glyph into [canvas], scaled from the web
/// platform's 14x14 SVG legend icons (reproduced here as vector paths) so
/// every place this app shows a category icon matches 911rescueme.com
/// pixel-for-pixel instead of approximating with a generic Material icon —
/// notably Police is a smooth shield outline (not a badge-with-star) and
/// Fire is a plain pentagon (not a flame).
///
/// Draws into the unit square `(0,0)`–`(size,size)` at the canvas's current
/// origin; callers that need it elsewhere (e.g. centered in a marker
/// circle) should `canvas.translate(...)` first.
void paintFacilityCategoryGlyph(
  Canvas canvas,
  FacilityCategory category,
  Color color,
  double size,
) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;
  canvas.save();
  canvas.scale(size / 14);
  switch (category) {
    case FacilityCategory.health:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 1, 4, 12),
          const Radius.circular(0.5),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(1, 5, 12, 4),
          const Radius.circular(0.5),
        ),
        paint,
      );
    case FacilityCategory.other:
      canvas.drawCircle(const Offset(7, 7), 6, paint);
    case FacilityCategory.police:
      final path = Path()
        ..moveTo(7, 1)
        ..lineTo(13, 3)
        ..lineTo(13, 8)
        ..cubicTo(13, 11, 10, 13, 7, 13)
        ..cubicTo(4, 13, 1, 11, 1, 8)
        ..lineTo(1, 3)
        ..close();
      canvas.drawPath(path, paint);
    case FacilityCategory.fire:
      final path = Path()
        ..moveTo(7, 0)
        ..lineTo(14, 5)
        ..lineTo(11.5, 14)
        ..lineTo(2.5, 14)
        ..lineTo(0, 5)
        ..close();
      canvas.drawPath(path, paint);
    case FacilityCategory.roadSafety:
      final path = Path()
        ..moveTo(7, 1)
        ..lineTo(13, 13)
        ..lineTo(1, 13)
        ..close();
      canvas.drawPath(path, paint);
  }
  canvas.restore();
}

/// Widget wrapper around [paintFacilityCategoryGlyph] for use in the normal
/// widget tree (legend, filter chips, facility popups) — [_renderCategoryMarker]
/// in `MapAnnotationController` calls the paint function directly since it
/// draws onto a raw [Canvas], not through a widget.
class FacilityCategoryGlyph extends StatelessWidget {
  const FacilityCategoryGlyph({
    super.key,
    required this.category,
    required this.color,
    this.size = 16,
  });

  final FacilityCategory category;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FacilityCategoryGlyphPainter(category: category, color: color),
    );
  }
}

class _FacilityCategoryGlyphPainter extends CustomPainter {
  _FacilityCategoryGlyphPainter({required this.category, required this.color});

  final FacilityCategory category;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      paintFacilityCategoryGlyph(canvas, category, color, size.width);

  @override
  bool shouldRepaint(covariant _FacilityCategoryGlyphPainter oldDelegate) =>
      oldDelegate.category != category || oldDelegate.color != color;
}
