import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The web console's page: one bordered card, centred, scrolling.
class ConsolePage extends StatelessWidget {
  const ConsolePage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.backgroundCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.palette.backgroundSurface,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: context.palette.primary),
                  boxShadow: [
                    BoxShadow(
                      color: context.palette.shadow,
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Responder Console" in the web's blue-to-green gradient.
class GradientTitle extends StatelessWidget {
  const GradientTitle(this.text, {super.key, this.fontSize = 22});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: [context.palette.primary, context.palette.accentGreen],
      ).createShader(bounds),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// One of the console's bordered sections.
class ConsoleSection extends StatelessWidget {
  const ConsoleSection({
    super.key,
    required this.child,
    this.borderColor,
    this.borderWidth = 1,
    this.background,
  });

  final Widget child;
  final Color? borderColor;
  final double borderWidth;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: borderColor ?? context.palette.border,
          width: borderWidth,
        ),
      ),
      child: child,
    );
  }
}
