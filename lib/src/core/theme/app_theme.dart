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
}

abstract final class AppRadii {
  static const sm = 6.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const full = 999.0;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      error: AppColors.danger,
      surface: AppColors.backgroundSurface,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundCanvas,
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
    );
  }
}
