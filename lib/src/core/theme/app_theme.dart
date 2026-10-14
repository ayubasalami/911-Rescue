import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF0077FF);
  static const danger = Color(0xFFD9004C);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const backgroundCanvas = Color(0xFFF4F6F8);
  static const backgroundSurface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF121212);
  static const textSecondary = Color(0xFF666666);
  static const border = Color(0xFFE2E5E9);

  /// The drawer's "Lagos Boundary" map layer outline — a distinct teal so
  /// it doesn't read as a route (primary blue) or traffic (success green).
  static const boundary = Color(0xFF06B6D4);
}

abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const full = 999.0;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    // Material 3 derives every surface role from the seed, which gives
    // dialogs, sheets, the drawer and menus a faint blue-lavender tint. The
    // web paints all of its panels plain white (`--panel-bg`), so pin the
    // surface roles — and drop the elevation tint — to match.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      error: AppColors.danger,
      surface: AppColors.backgroundSurface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: AppColors.backgroundSurface,
      surfaceContainerLow: AppColors.backgroundSurface,
      surfaceContainer: AppColors.backgroundSurface,
      surfaceContainerHigh: AppColors.backgroundSurface,
      surfaceContainerHighest: AppColors.backgroundCanvas,
      outlineVariant: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundCanvas,
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.backgroundSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.backgroundSurface,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.backgroundSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.backgroundSurface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.backgroundSurface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundSurface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
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
