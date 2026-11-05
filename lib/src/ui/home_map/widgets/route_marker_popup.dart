import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum RouteMarkerPopupKind { start, destination }

/// The web's popup on a route's markers: "📍 Start Point" in blue, the
/// destination in green.
class RouteMarkerPopup extends StatelessWidget {
  const RouteMarkerPopup({super.key, required this.kind, required this.text});

  final RouteMarkerPopupKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Material(
        color: palette.backgroundSurface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        elevation: 8,
        shadowColor: Colors.black26,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kind == RouteMarkerPopupKind.start
                  ? palette.primary
                  : palette.accentGreen,
            ),
          ),
        ),
      ),
    );
  }
}
