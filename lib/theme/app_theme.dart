import 'package:flutter/material.dart';

class AppColors {
  // App colors based on provided palette
  static const Color primary = Color.fromARGB(255, 49, 73, 103);
  static const Color secondary = Color.fromRGBO(130, 149, 255, 1);
  static const Color accent1 = Color.fromARGB(255, 61, 66, 130);
  static const Color accent2 = Color.fromARGB(255, 214, 155, 180);
  static const Color accent3 = Color.fromARGB(255, 146, 83, 128);
  static const Color background = Color(0xFFF5F5FF);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color textPrimary = Color.fromARGB(255, 45, 53, 89);
  static const Color textSecondary = Color.fromARGB(255, 80, 86, 152);
}

class AppTheme {
  // Light theme
  static final ThemeData lightTheme = ThemeData(
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent2,
      surface: AppColors.background,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppColors.primary),
      titleTextStyle: TextStyle(
        color: AppColors.primary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge:
          TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      displayMedium:
          TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      displaySmall:
          TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      headlineMedium:
          TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      headlineSmall:
          TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleLarge:
          TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.textPrimary),
      titleSmall: TextStyle(color: AppColors.textSecondary),
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent2,
        foregroundColor: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.accent1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardTheme(
      color: AppColors.white,
      elevation: 2,
      shadowColor: AppColors.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}
