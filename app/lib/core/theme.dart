import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Giao dien theo DESIGN-apple.md:
// - Chi MOT mau tuong tac: AppColors.primary (#0066cc).
// - Khong do bong, khong gradient trang tri; phan cap bang mau nen + vien hairline.
// - Thang dam chu 400 / 600 (khong dung 500, 800).

/// Token mau.
class AppColors {
  AppColors._();

  // Tuong tac (link, nut, focus)
  static const primary = Color(0xFF0066CC);
  static const primaryFocus = Color(0xFF0071E3);
  static const primaryOnDark = Color(0xFF2997FF);

  // Chu
  static const ink = Color(0xFF1D1D1F);
  static const inkMuted80 = Color(0xFF333333);
  static const inkMuted48 = Color(0xFF7A7A7A);
  static const bodyOnDark = Color(0xFFFFFFFF);
  static const bodyMuted = Color(0xFFCCCCCC);

  // Be mat
  static const canvas = Color(0xFFFFFFFF);
  static const parchment = Color(0xFFF5F5F7);
  static const pearl = Color(0xFFFAFAFC);
  static const tile1 = Color(0xFF272729);
  static const surfaceBlack = Color(0xFF000000);

  /// #d2d2d7 o ~64% alpha: chip tron / nhan de len anh.
  static const chipTranslucent = Color(0xA3D2D2D7);

  // Duong ke
  static const hairline = Color(0xFFE0E0E0);
  static const dividerSoft = Color(0xFFF0F0F0);

  // Trang thai ngan sach (BR-04). File thiet ke khong dinh nghia mau trang thai
  // nen chi dung o nhan "sap het" / "vuot", khong dung cho phan tu tuong tac.
  static const warning = Color(0xFFB25000);
  static const danger = Color(0xFFD70015);
}

/// Bo goc.
class AppRadius {
  AppRadius._();

  static const double xs = 5;
  static const double sm = 8; // anh trong the, o lich
  static const double md = 11;
  static const double lg = 18; // the (utility card)
  static const double pill = 999; // nut chinh, chip, o tim kiem
}

/// Khoang cach (co so 8px).
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 17;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Kieu chu. Khong khai bao fontFamily: font lay tu theme
/// (SF Pro tren iOS, Inter tren Android - ban thay the gan nhat theo file thiet ke).
class AppText {
  AppText._();

  static const displayLg = TextStyle(
    fontSize: 40, fontWeight: FontWeight.w600, height: 1.1, letterSpacing: 0,
    color: AppColors.ink,
  );
  static const displayMd = TextStyle(
    fontSize: 34, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: -0.374,
    color: AppColors.ink,
  );
  static const tagline = TextStyle(
    fontSize: 21, fontWeight: FontWeight.w600, height: 1.19, letterSpacing: 0.231,
    color: AppColors.ink,
  );
  static const bodyStrong = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600, height: 1.24, letterSpacing: -0.374,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w400, height: 1.47, letterSpacing: -0.374,
    color: AppColors.ink,
  );
  static const caption = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.43, letterSpacing: -0.224,
    color: AppColors.ink,
  );
  static const captionStrong = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600, height: 1.29, letterSpacing: -0.224,
    color: AppColors.ink,
  );
  static const finePrint = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, height: 1.0, letterSpacing: -0.12,
    color: AppColors.ink,
  );
  static const micro = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w400, height: 1.3, letterSpacing: -0.08,
    color: AppColors.ink,
  );
}

bool get _isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

TextTheme _buildTextTheme() {
  const theme = TextTheme(
    displayLarge: AppText.displayLg,
    displayMedium: AppText.displayLg,
    displaySmall: AppText.displayLg,
    headlineLarge: AppText.displayLg,
    headlineMedium: AppText.displayMd,
    headlineSmall: AppText.tagline,
    titleLarge: AppText.tagline,
    titleMedium: AppText.bodyStrong,
    titleSmall: AppText.captionStrong,
    bodyLarge: AppText.body,
    bodyMedium: AppText.body, // chu mac dinh 17px
    bodySmall: AppText.caption,
    labelLarge: AppText.body, // chu tren nut
    labelMedium: AppText.caption,
    labelSmall: AppText.finePrint,
  );
  // iOS dung san font he thong (SF Pro); Android dung Inter.
  return _isApplePlatform ? theme : GoogleFonts.interTextTheme(theme);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.canvas,
    onSurface: AppColors.ink,
    outline: AppColors.hairline,
    outlineVariant: AppColors.hairline,
    error: AppColors.danger,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: _buildTextTheme(),
    scaffoldBackgroundColor: AppColors.parchment,
    dividerColor: AppColors.hairline,
    // Khong hieu ung loang mau khi cham; nhan thi thu nho (xem Pressable)
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  final text = base.textTheme;

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.parchment,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: text.titleMedium,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.inkMuted48,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelSmall?.copyWith(
            color: selected ? AppColors.primary : AppColors.inkMuted48,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          );
        },
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: const StadiumBorder(),
        textStyle: text.bodySmall,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.hairline)),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        textStyle: WidgetStatePropertyAll(text.bodySmall),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.canvas,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.ink,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.ink,
      linearTrackColor: AppColors.dividerSoft,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      elevation: 0,
      contentTextStyle: text.bodySmall?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  );
}
