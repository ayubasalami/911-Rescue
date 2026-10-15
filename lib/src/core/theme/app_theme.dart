import 'package:flutter/material.dart';

/// The app's colours for one brightness, mirroring the web's CSS variables
/// (`:root` for [light], `body.dark-mode` for [dark]). Read it with
/// `context.palette` so widgets follow the theme.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.danger,
    required this.success,
    required this.warning,
    required this.backgroundCanvas,
    required this.backgroundSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.boundary,
    required this.inputBg,
    required this.hoverBg,
    required this.accentGreen,
    required this.accentYellow,
    required this.route,
    required this.onAccent,
    required this.shadow,
  });

  /// `--accent-blue`.
  final Color primary;

  /// `--accent-pink`.
  final Color danger;
  final Color success;
  final Color warning;

  /// `--bg-color`.
  final Color backgroundCanvas;

  /// `--panel-bg`.
  final Color backgroundSurface;

  /// `--text-main`.
  final Color textPrimary;

  /// `--text-muted`.
  final Color textSecondary;

  /// `--border-color`.
  final Color border;

  /// The drawer's "Lagos Boundary" map layer outline — the web's dashed
  /// `#00e5ff`, in both themes.
  final Color boundary;

  /// `--input-bg`.
  final Color inputBg;

  /// `--hover-bg`.
  final Color hoverBg;

  /// `--accent-green`.
  final Color accentGreen;

  /// `--accent-yellow`.
  final Color accentYellow;

  /// `--route-color`.
  final Color route;

  /// `--btn-text`: text and icons on [primary] and [accentGreen] fills.
  final Color onAccent;

  /// `--shadow-color`.
  final Color shadow;

  static const light = AppPalette(
    primary: Color(0xFF0077FF),
    danger: Color(0xFFD9004C),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    backgroundCanvas: Color(0xFFF4F6F8),
    backgroundSurface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF121212),
    textSecondary: Color(0xFF666666),
    border: Color(0xFFE2E5E9),
    boundary: Color(0xFF00E5FF),
    inputBg: Color(0xFFF0F2F5),
    hoverBg: Color(0xFFE4E6E9),
    accentGreen: Color(0xFF00AA55),
    accentYellow: Color(0xFFCCA600),
    route: Color(0xFF0066FF),
    onAccent: Color(0xFFFFFFFF),
    shadow: Color(0x1A000000),
  );

  static const dark = AppPalette(
    primary: Color(0xFF00E5FF),
    danger: Color(0xFFFF0055),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    backgroundCanvas: Color(0xFF121212),
    backgroundSurface: Color(0xFF1E1E1E),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFAAAAAA),
    border: Color(0xFF333333),
    boundary: Color(0xFF00E5FF),
    inputBg: Color(0xFF2A2A2A),
    hoverBg: Color(0xFF333333),
    accentGreen: Color(0xFF00FF88),
    accentYellow: Color(0xFFFFEA00),
    route: Color(0xFFFFEA00),
    onAccent: Color(0xFF000000),
    shadow: Color(0x80000000),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      primary: mix(primary, other.primary),
      danger: mix(danger, other.danger),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      backgroundCanvas: mix(backgroundCanvas, other.backgroundCanvas),
      backgroundSurface: mix(backgroundSurface, other.backgroundSurface),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      border: mix(border, other.border),
      boundary: mix(boundary, other.boundary),
      inputBg: mix(inputBg, other.inputBg),
      hoverBg: mix(hoverBg, other.hoverBg),
      accentGreen: mix(accentGreen, other.accentGreen),
      accentYellow: mix(accentYellow, other.accentYellow),
      route: mix(route, other.route),
      onAccent: mix(onAccent, other.onAccent),
      shadow: mix(shadow, other.shadow),
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// The current theme's [AppPalette].
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const full = 999.0;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    // Material 3 derives every surface role from the seed, which gives
    // dialogs, sheets, the drawer and menus a faint blue-lavender tint. The
    // web paints all of its panels plain (`--panel-bg`), so pin the surface
    // roles — and drop the elevation tint — to match.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      primary: palette.primary,
      onPrimary: palette.onAccent,
      error: palette.danger,
      surface: palette.backgroundSurface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: palette.backgroundSurface,
      surfaceContainerLow: palette.backgroundSurface,
      surfaceContainer: palette.backgroundSurface,
      surfaceContainerHigh: palette.backgroundSurface,
      surfaceContainerHighest: palette.backgroundCanvas,
      outlineVariant: palette.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      colorScheme: colorScheme,
      extensions: [palette],
      scaffoldBackgroundColor: palette.backgroundCanvas,
      dialogTheme: DialogThemeData(
        backgroundColor: palette.backgroundSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.backgroundSurface,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.backgroundSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: palette.backgroundSurface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.backgroundSurface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: palette.border),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.backgroundSurface,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      // Material 3's default OutlinedButton is a full stadium/pill shape —
      // without this override it visibly mismatches the rounded-rect
      // ElevatedButtons above. Any bare OutlinedButton (e.g. one with
      // custom composed content that doesn't fit AppButton) still gets the
      // right radius for free.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }
}
