import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFF08080E);
  static const surface = Color(0xFF12121C);
  static const surfaceHigh = Color(0xFF1C1C2B);
  static const stroke = Color(0x1FFFFFFF);
  static const text = Color(0xFFF4F4F8);
  static const textDim = Color(0xFF9D9DB4);
  static const accent = Color(0xFFFF3D6E);
  static const accent2 = Color(0xFFFF9F43);
  static const success = Color(0xFF2ED47A);
  static const danger = Color(0xFFFF5A76);

  static const gradient = LinearGradient(
    colors: [accent, accent2],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

abstract final class AppFonts {
  static const body = 'Outfit';
  static const display = 'BebasNeue';
}

TextStyle displayStyle(double size, {Color color = AppColors.text}) =>
    TextStyle(
      fontFamily: AppFonts.display,
      fontSize: size,
      height: 1.0,
      letterSpacing: 1.2,
      color: color,
    );

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.accent,
        secondary: AppColors.accent2,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.danger,
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: AppFonts.body,
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(
        fontFamily: AppFonts.body,
        color: AppColors.text,
      ),
      actionTextColor: AppColors.accent2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      hintStyle: const TextStyle(color: AppColors.textDim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
  );
}
