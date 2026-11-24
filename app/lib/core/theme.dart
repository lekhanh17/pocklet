// Ban Flutter moi chuyen CupertinoPageTransitionsBuilder sang thu vien cupertino
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Giao dien am ap kieu game nuoi thu (dot 4):
// - Nen kem, chu nau, MOT mau tuong tac la xanh la (AppColors.primary).
// - Phong cua pet dung bo mau rieng (room*), con lai dung chung token.
// - Font Nunito bo tron; tieu de dam (800) cho cam giac de thuong.

/// Token mau.
class AppColors {
  AppColors._();

  // Tuong tac (link, nut, focus). Chu trang tren #3B6D11 dat tuong phan > 4.5:1
  static const primary = Color(0xFF3B6D11);
  static const primaryFocus = Color(0xFF639922);
  static const primaryOnDark = Color(0xFFC0DD97);

  // Chu (nau)
  static const ink = Color(0xFF412402);
  static const inkMuted80 = Color(0xFF633806);
  static const inkMuted48 = Color(0xFF7D5A36);
  static const bodyOnDark = Color(0xFFFFFFFF);
  static const bodyMuted = Color(0xFFE8D9C4);

  // Be mat
  static const canvas = Color(0xFFFFFCF6);
  static const parchment = Color(0xFFFBF1E1);
  static const pearl = Color(0xFFFFF8EE);
  static const tile1 = Color(0xFF2E2622);
  static const surfaceBlack = Color(0xFF000000);

  /// Kem 90%: chip / nhan de len anh.
  static const chipTranslucent = Color(0xE6FFF8EE);

  // Duong ke
  static const hairline = Color(0xFFEAD3B0);
  static const dividerSoft = Color(0xFFF3E4CC);

  // Trang thai ngan sach (BR-04), chi dung cho nhan, khong dung cho nut
  static const warning = Color(0xFFB25000);
  static const danger = Color(0xFFC62828);

  // Phong cua pet
  static const roomWall = Color(0xFFFFF4E2);
  static const roomWindow = Color(0xFFB5D4F4);
  static const roomWindowFrame = Color(0xFFFFFFFF);
  static const roomCurtain = Color(0xFFC0DD97);
  static const roomCurtainShade = Color(0xFF97C459);
  static const roomFloor = Color(0xFFF6DDB0);
  static const roomFloorLine = Color(0xFFE9C58C);
  static const roomRug = Color(0xFFEF9F27);
  static const roomTrim = Color(0xFF854F0B);
  static const roomBorder = Color(0xFFFAC775);
  static const coin = Color(0xFFEF9F27);
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

/// Kieu chu. Khong khai bao fontFamily: font lay tu theme (Nunito).
class AppText {
  AppText._();

  static const displayLg = TextStyle(
    fontSize: 40, fontWeight: FontWeight.w800, height: 1.1, color: AppColors.ink,
  );
  static const displayMd = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.ink,
  );
  static const tagline = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.ink,
  );
  static const bodyStrong = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w700, height: 1.25, color: AppColors.ink,
  );
  static const body = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w400, height: 1.45, color: AppColors.ink,
  );
  static const caption = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: AppColors.ink,
  );
  static const captionStrong = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.ink,
  );
  static const finePrint = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, height: 1.15, color: AppColors.ink,
  );
  static const micro = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w400, height: 1.3, color: AppColors.ink,
  );
}

TextTheme _buildTextTheme() {
  const theme = TextTheme(
    displayLarge: AppText.displayLg,
    displayMedium: AppText.displayLg,
    displaySmall: AppText.displayLg,
    headlineLarge: AppText.displayLg,
    headlineMedium: AppText.displayMd, // tieu de lon cua SliverAppBar.large
    headlineSmall: AppText.tagline,
    titleLarge: AppText.tagline, // tieu de AppBar khi thu nho
    titleMedium: AppText.bodyStrong,
    titleSmall: AppText.captionStrong,
    bodyLarge: AppText.body,
    bodyMedium: AppText.body, // chu mac dinh 17px
    bodySmall: AppText.caption,
    labelLarge: AppText.bodyStrong, // chu tren nut
    labelMedium: AppText.caption,
    labelSmall: AppText.finePrint,
  );
  return GoogleFonts.nunitoTextTheme(theme);
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
    // Chuyen man kieu iOS tren ca Android: truot ngang, form truot tu duoi len
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.parchment,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
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