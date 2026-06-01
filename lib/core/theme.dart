import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeLevel { blush, sunset, midnight, deepSpace }

@immutable
class DadyTubeThemeTokens extends ThemeExtension<DadyTubeThemeTokens> {
  final Color backgroundGradientStart;
  final Color backgroundGradientEnd;
  final Color particleColor;
  final Color glassTint;
  final Color cardBorder;
  final Color cardShadow;
  final Color accentSoft;
  final Color accentStrong;
  final Color navActive;
  final Color navInactive;
  final Color playerPanel;
  final Color playerPanelBorder;
  final Color highlight;

  const DadyTubeThemeTokens({
    required this.backgroundGradientStart,
    required this.backgroundGradientEnd,
    required this.particleColor,
    required this.glassTint,
    required this.cardBorder,
    required this.cardShadow,
    required this.accentSoft,
    required this.accentStrong,
    required this.navActive,
    required this.navInactive,
    required this.playerPanel,
    required this.playerPanelBorder,
    required this.highlight,
  });

  @override
  DadyTubeThemeTokens copyWith({
    Color? backgroundGradientStart,
    Color? backgroundGradientEnd,
    Color? particleColor,
    Color? glassTint,
    Color? cardBorder,
    Color? cardShadow,
    Color? accentSoft,
    Color? accentStrong,
    Color? navActive,
    Color? navInactive,
    Color? playerPanel,
    Color? playerPanelBorder,
    Color? highlight,
  }) {
    return DadyTubeThemeTokens(
      backgroundGradientStart:
          backgroundGradientStart ?? this.backgroundGradientStart,
      backgroundGradientEnd: backgroundGradientEnd ?? this.backgroundGradientEnd,
      particleColor: particleColor ?? this.particleColor,
      glassTint: glassTint ?? this.glassTint,
      cardBorder: cardBorder ?? this.cardBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      accentSoft: accentSoft ?? this.accentSoft,
      accentStrong: accentStrong ?? this.accentStrong,
      navActive: navActive ?? this.navActive,
      navInactive: navInactive ?? this.navInactive,
      playerPanel: playerPanel ?? this.playerPanel,
      playerPanelBorder: playerPanelBorder ?? this.playerPanelBorder,
      highlight: highlight ?? this.highlight,
    );
  }

  @override
  DadyTubeThemeTokens lerp(
    covariant ThemeExtension<DadyTubeThemeTokens>? other,
    double t,
  ) {
    if (other is! DadyTubeThemeTokens) return this;
    return DadyTubeThemeTokens(
      backgroundGradientStart: Color.lerp(
        backgroundGradientStart,
        other.backgroundGradientStart,
        t,
      )!,
      backgroundGradientEnd: Color.lerp(
        backgroundGradientEnd,
        other.backgroundGradientEnd,
        t,
      )!,
      particleColor: Color.lerp(particleColor, other.particleColor, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      navActive: Color.lerp(navActive, other.navActive, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      playerPanel: Color.lerp(playerPanel, other.playerPanel, t)!,
      playerPanelBorder: Color.lerp(
        playerPanelBorder,
        other.playerPanelBorder,
        t,
      )!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
    );
  }
}

class DadyTubeTheme {
  // --- Constants ---
  static const double borderRadiusLarge = 32.0;
  static const double borderRadiusMedium = 24.0;
  static const double borderRadiusSmall = 16.0;
  static const double borderRadiusFull = 9999.0;

  static DadyTubeThemeTokens tokens(BuildContext context) =>
      Theme.of(context).extension<DadyTubeThemeTokens>()!;

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
          tokens: const DadyTubeThemeTokens(
            backgroundGradientStart: Color(0xFFFFF8FB),
            backgroundGradientEnd: Color(0xFFFFE3EC),
            particleColor: Color(0xFFF6A3BC),
            glassTint: Color(0xFFFDF7F9),
            cardBorder: Color(0xFFF8D7E3),
            cardShadow: Color(0x1AE15A8B),
            accentSoft: Color(0xFFFFE7EF),
            accentStrong: Color(0xFFE91E63),
            navActive: Color(0xFFE91E63),
            navInactive: Color(0xFF9D7B88),
            playerPanel: Color(0xFFFFFBFC),
            playerPanelBorder: Color(0xFFF7D4E1),
            highlight: Color(0xFFFFC6D7),
          ),
        );
      case AppThemeLevel.sunset:
        return _buildTheme(
          background: const Color(0xFFFFF1E6),
          primary: const Color(0xFFD85E3A),
          primaryContainer: const Color(0xFFFFC7A8),
          secondary: const Color(0xFFEF8B58),
          surface: const Color(0xFFFFF7F2),
          onBackground: const Color(0xFF5C3428),
          isDark: false,
          tokens: const DadyTubeThemeTokens(
            backgroundGradientStart: Color(0xFFFFF5EC),
            backgroundGradientEnd: Color(0xFFFFDCC7),
            particleColor: Color(0xFFF6AA76),
            glassTint: Color(0xFFFFFBF6),
            cardBorder: Color(0xFFF7D6BF),
            cardShadow: Color(0x1ACB6F40),
            accentSoft: Color(0xFFFFE6D6),
            accentStrong: Color(0xFFD85E3A),
            navActive: Color(0xFFD85E3A),
            navInactive: Color(0xFFA17A68),
            playerPanel: Color(0xFFFFFCF8),
            playerPanelBorder: Color(0xFFF5D7C4),
            highlight: Color(0xFFFFD18C),
          ),
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
          tokens: const DadyTubeThemeTokens(
            backgroundGradientStart: Color(0xFF1A1A2E),
            backgroundGradientEnd: Color(0xFF101728),
            particleColor: Color(0xFF4CC9F0),
            glassTint: Color(0xFF202A44),
            cardBorder: Color(0xFF283556),
            cardShadow: Color(0x66060A16),
            accentSoft: Color(0xFF223252),
            accentStrong: Color(0xFFFF2E63),
            navActive: Color(0xFF08D9D6),
            navInactive: Color(0xFF7E8DAA),
            playerPanel: Color(0xFF18243C),
            playerPanelBorder: Color(0xFF2B3C62),
            highlight: Color(0xFF40E0D0),
          ),
        );
      case AppThemeLevel.deepSpace:
        return _buildTheme(
          background: const Color(0xFF0F0F0F),
          primary: const Color(0xFF4DA3FF),
          primaryContainer: const Color(0xFF1B1E27),
          secondary: const Color(0xFFFFD166),
          surface: const Color(0xFF11141B),
          onBackground: Colors.white,
          isDark: true,
          tokens: const DadyTubeThemeTokens(
            backgroundGradientStart: Color(0xFF101216),
            backgroundGradientEnd: Color(0xFF050608),
            particleColor: Color(0xFF6FB7FF),
            glassTint: Color(0xFF181C24),
            cardBorder: Color(0xFF242A35),
            cardShadow: Color(0x80000000),
            accentSoft: Color(0xFF171E29),
            accentStrong: Color(0xFF4DA3FF),
            navActive: Color(0xFF4DA3FF),
            navInactive: Color(0xFF7A879A),
            playerPanel: Color(0xFF121722),
            playerPanelBorder: Color(0xFF293140),
            highlight: Color(0xFFFFD166),
          ),
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
    required DadyTubeThemeTokens tokens,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
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
      extensions: [tokens],
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
      dividerColor: tokens.cardBorder,
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
