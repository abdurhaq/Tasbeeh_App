import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF080808); // pure OLED black
  static const Color surface = Color(0xFF111111); // card surface
  static const Color surfaceLight = Color(0xFF1A1A1A); // elevated surface

  // Gold accent system
  static const Color gold = Color(0xFFD4A853); // primary gold
  static const Color goldLight = Color(0xFFF0C97A); // highlight gold
  static const Color goldDark = Color(0xFF9A7335); // muted gold

  // Text
  static const Color textPrimary = Color(0xFFF5F0E8); // warm white
  static const Color textSecond = Color(0xFF9A9080); // muted warm grey
  static const Color textHint = Color(0xFF4A4540); // very muted

  // Dhikr colors (for ring progress)
  static const List<Color> dhikrColors = [
    Color(0xFF4ADE80), // green
    Color(0xFF60A5FA), // blue
    Color(0xFFF472B6), // pink
    Color(0xFFFB923C), // orange
    Color(0xFFA78BFA), // purple
    Color(0xFFFBBF24), // yellow
  ];
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.gold,
        onPrimary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
      fontFamily: GoogleFonts.lato().fontFamily,
      textTheme: const TextTheme(
        // Arabic display text
        displayLarge: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        // Transliteration
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w300,
          color: AppColors.textSecond,
          letterSpacing: 1.2,
        ),
        // Translation
        bodyMedium: TextStyle(
          fontSize: 13,
          color: AppColors.textHint,
          letterSpacing: 0.5,
        ),
        // Counter number
        displayMedium: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -2,
        ),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
