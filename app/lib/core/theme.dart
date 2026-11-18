import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mau theo huong giao dien B - Nhat ky anh (dac ta muc 5).
class AppColors {
  AppColors._();

  static const background = Color(0xFFF6F4F0);
  static const surface = Color(0xFFFFFFFF);
  static const accent = Color(0xFF0F766E);
  static const accentSoft = Color(0xFFE3F1EF);
  static const textPrimary = Color(0xFF1C1917);
  static const textMuted = Color(0xFF78716C);
  static const border = Color(0xFFE7E2DA);
  static const borderStrong = Color(0xFFC9C2B8);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    surface: AppColors.background,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
  );

  return base.copyWith(
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accentSoft,
      height: 68,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}
