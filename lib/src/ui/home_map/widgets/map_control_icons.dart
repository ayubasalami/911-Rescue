import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The right-side map control icons, copied verbatim from the web
/// platform's own button markup (Feather-style outline icons) so they
/// match exactly rather than approximating with Material icons. Each SVG
/// strokes in `currentColor`, which [MapControlIcon] fills in.
enum MapControlIcon {
  locate('<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="3"/>'),
  home(
    '<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'
    '<polyline points="9 22 9 12 15 12 15 22"/>',
  ),
  search(
    '<circle cx="11" cy="11" r="8"/>'
    '<line x1="21" y1="21" x2="16.65" y2="16.65"/>',
    strokeWidth: 2.5,
    scale: 16 / 18,
  ),
  routePlanner('<polygon points="3 11 22 2 13 21 11 13 3 11"/>'),
  legend(
    '<line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/>'
    '<line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/>'
    '<line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>',
  ),
  clear(
    '<polyline points="3 6 5 6 21 6"/>'
    '<path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
    scale: 16 / 18,
  ),
  traffic(
    '<path d="M15 6v12a3 3 0 1 1-6 0V6a3 3 0 1 1 6 0Z"/>'
    '<path d="M12 3v3"/><path d="M12 18v3"/>',
    scale: 17 / 18,
  );

  const MapControlIcon(this._body, {this.strokeWidth = 2, this.scale = 1});

  final String _body;
  final double strokeWidth;

  /// Relative to the standard icon — the web draws search/clear at 16px and
  /// traffic at 17px where the rest are 18px.
  final double scale;

  String svgFor(Color color) {
    final hex =
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return '<svg viewBox="0 0 24 24" fill="none" stroke="$hex" '
        'stroke-width="$strokeWidth" stroke-linecap="round" '
        'stroke-linejoin="round">$_body</svg>';
  }

  Widget build({required Color color, required double size}) {
    final s = size * scale;
    return SvgPicture.string(svgFor(color), width: s, height: s);
  }
}
