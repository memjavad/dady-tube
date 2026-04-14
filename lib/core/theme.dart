import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeLevel { blush, sunset, midnight, deepSpace }

class DadyTubeTheme {
  // --- Constants ---
  static const double borderRadiusLarge = 32.0;
  static const double borderRadiusFull = 9999.0;

  static ThemeData getTheme(AppThemeLevel level) {
    switch (level) {
      case AppThemeLevel.blush:
        return _buildTheme(
          background: const Color(0xFFFFF5F7),
          primary: const Color(0xFFE91E63),
          primaryContainer: const Color(0xFFFFB8CD),
          secondary: const Color(0xFFD81B60),
          surface: Colors.white,
          onBackground: const Color(0xFF3E2723),
          isDark: false,
        );
      case AppThemeLevel.sunset:
        return _buildTheme(
          background: const Color(0xFFFFE0E5),
          primary: const Color(0xFFC2185B),
          primaryContainer: const Color(0xFFF48FB1),
          secondary: const Color(0xFFAD1457),
          surface: const Color(0xFFFFF0F3),
          onBackground: const Color(0xFF4A148C),
          isDark: false,
        );
      case AppThemeLevel.midnight:
        return _buildTheme(
          background: const Color(0xFF1A1A2E),
          primary: const Color(0xFFFF2E63),
          primaryContainer: const Color(0xFF252A34),
          secondary: const Color(0xFF08D9D6),
          surface: const Color(0xFF16213E),
          onBackground: Colors.white,
          isDark: true,
        );
      case AppThemeLevel.deepSpace:
        return _buildTheme(
          background: const Color(0xFF0F0F0F),
          primary: const Color(0xFFE91E63),
          primaryContainer: const Color(0xFF1E1E1E),
          secondary: const Color(0xFFFFB8CD),
          surface: const Color(0xFF121212),
          onBackground: Colors.white,
          isDark: true,
        );
    }
  }

  static ThemeData _buildTheme({
    required Color background,
    required Color primary,
    required Color primaryContainer,
    required Color secondary,
    required Color surface,
    required Color onBackground,
    required bool isDark,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
      background: background,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: isDark ? Colors.white : primary,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: onBackground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme:
          GoogleFonts.beVietnamProTextTheme(
                GoogleFonts.almaraiTextTheme().apply(
                  bodyColor: onBackground,
                  displayColor: onBackground,
                ),
              )
              .apply(bodyColor: onBackground, displayColor: onBackground)
              .copyWith(
                displayLarge: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: onBackground,
                ),
                displayMedium: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: onBackground,
                ),
                displaySmall: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: onBackground,
                ),
                headlineMedium: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: onBackground,
                ),
                titleLarge: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: onBackground,
                ),
                titleMedium: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: onBackground,
                ),
                labelLarge: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: onBackground,
                ),
              ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: isDark ? Colors.white : primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusFull),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
        ),
      ),
    );
  }

  // Backwards compatibility for now
  static ThemeData get lightTheme => getTheme(AppThemeLevel.blush);

  // Static colors for legacy/static references
  static const Color background = Color(0xFFFFF5F7);
  static const Color primary = Color(0xFFE91E63);
  static const Color primaryContainer = Color(0xFFFFB8CD);
  static const Color surface = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFFFEBF0);
  static const Color onBackground = Color(0xFF3E2723);
}
