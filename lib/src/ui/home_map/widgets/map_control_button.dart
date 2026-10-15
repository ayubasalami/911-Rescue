import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A square map control, styled like the web platform's mobile controls:
/// always white with a 1px #ddd border and 4px corners. On/off state is
/// shown by the [icon]'s own color (e.g. blue legend, amber traffic), not
/// by filling the button.
class MapControlButton extends StatelessWidget {
  const MapControlButton({super.key, required this.icon, required this.onTap});

  final Widget icon;
  final VoidCallback onTap;

  static const _radius = BorderRadius.all(Radius.circular(4));

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.backgroundSurface,
      borderRadius: _radius,
      child: InkWell(
        borderRadius: _radius,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: _radius,
            border: Border.all(color: context.palette.border),
          ),
          child: icon,
        ),
      ),
    );
  }
}
