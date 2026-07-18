import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppTextStyles.fontFamily,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
    ),

    cardColor: AppColors.card,
    dividerColor: AppColors.divider,

    iconTheme: const IconThemeData(color: AppColors.primary, size: 24),

    textTheme:
        const TextTheme(
          headlineLarge: AppTextStyles.headingLarge,
          headlineMedium: AppTextStyles.headingMedium,
          headlineSmall: AppTextStyles.headingSmall,
          bodyLarge: AppTextStyles.bodyLarge,
          bodyMedium: AppTextStyles.bodyMedium,
          bodySmall: AppTextStyles.caption,
          labelLarge: AppTextStyles.button,
        ).apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),

    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: AppColors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      surfaceTintColor: AppColors.transparent,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.textPrimary,
      iconColor: AppColors.textSecondary,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: TextStyle(color: AppColors.textSecondary),
      helperStyle: TextStyle(color: AppColors.textSecondary),
      border: OutlineInputBorder(),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF111111),
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF111111),
      error: AppColors.error,
      outline: Color(0xFF737373),
      outlineVariant: Color(0xFFD4D4D4),
    ),
    scaffoldBackgroundColor: const Color(0xFFF4F6F8),
    fontFamily: AppTextStyles.fontFamily,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF4F6F8),
      foregroundColor: Color(0xFF111827),
      elevation: 0,
      centerTitle: true,
    ),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFD9DEE7),
    textTheme: const TextTheme(
      headlineLarge: AppTextStyles.headingLarge,
      headlineMedium: AppTextStyles.headingMedium,
      headlineSmall: AppTextStyles.headingSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.caption,
      labelLarge: AppTextStyles.button,
    ).apply(bodyColor: Color(0xFF111827), displayColor: Color(0xFF111827)),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Color(0xFF111827),
      iconColor: Color(0xFF4B5563),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFF4F6F8),
      labelStyle: TextStyle(color: Color(0xFF4B5563)),
      helperStyle: TextStyle(color: Color(0xFF4B5563)),
      prefixIconColor: Color(0xFF525252),
      suffixIconColor: Color(0xFF525252),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFD4D4D4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF111111), width: 1.5),
      ),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF111111)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
      ),
    ),
  );
}

class AppThemeController {
  AppThemeController._();

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  static void setStoredMode(String value) {
    mode.value = switch (value.trim().toLowerCase()) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }
}
