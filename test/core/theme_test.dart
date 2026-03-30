import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/core/theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // google_fonts tests require a special mock to avoid errors when testing offline
    // but the simplest fix for testing theme colors when fonts are hardcoded is to just run them and mock the assets channel
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DadyTubeTheme Tests', () {
    test('Static constants should match expected values', () {
      expect(DadyTubeTheme.borderRadiusLarge, 32.0);
      expect(DadyTubeTheme.borderRadiusFull, 9999.0);
    });

    testWidgets('lightTheme should match blush theme', (WidgetTester tester) async {
      final blushTheme = DadyTubeTheme.getTheme(AppThemeLevel.blush);
      final lightTheme = DadyTubeTheme.lightTheme;

      expect(blushTheme.scaffoldBackgroundColor, lightTheme.scaffoldBackgroundColor);
      expect(blushTheme.colorScheme.primary, lightTheme.colorScheme.primary);
    });

    group('getTheme mapping', () {
      testWidgets('blush theme properties', (WidgetTester tester) async {
        final theme = DadyTubeTheme.getTheme(AppThemeLevel.blush);
        expect(theme.scaffoldBackgroundColor, const Color(0xFFFFF5F7));
        expect(theme.colorScheme.primary, const Color(0xFFE91E63));
        expect(theme.colorScheme.primaryContainer, const Color(0xFFFFB8CD));
        expect(theme.colorScheme.secondary, const Color(0xFFD81B60));
        expect(theme.colorScheme.surface, Colors.white);
        expect(theme.colorScheme.onSurface, const Color(0xFF3E2723));
        expect(theme.colorScheme.brightness, Brightness.light);
      });

      testWidgets('sunset theme properties', (WidgetTester tester) async {
        final theme = DadyTubeTheme.getTheme(AppThemeLevel.sunset);
        expect(theme.scaffoldBackgroundColor, const Color(0xFFFFE0E5));
        expect(theme.colorScheme.primary, const Color(0xFFC2185B));
        expect(theme.colorScheme.primaryContainer, const Color(0xFFF48FB1));
        expect(theme.colorScheme.secondary, const Color(0xFFAD1457));
        expect(theme.colorScheme.surface, const Color(0xFFFFF0F3));
        expect(theme.colorScheme.onSurface, const Color(0xFF4A148C));
        expect(theme.colorScheme.brightness, Brightness.light);
      });

      testWidgets('midnight theme properties', (WidgetTester tester) async {
        final theme = DadyTubeTheme.getTheme(AppThemeLevel.midnight);
        expect(theme.scaffoldBackgroundColor, const Color(0xFF1A1A2E));
        expect(theme.colorScheme.primary, const Color(0xFFFF2E63));
        expect(theme.colorScheme.primaryContainer, const Color(0xFF252A34));
        expect(theme.colorScheme.secondary, const Color(0xFF08D9D6));
        expect(theme.colorScheme.surface, const Color(0xFF16213E));
        expect(theme.colorScheme.onSurface, Colors.white);
        expect(theme.colorScheme.brightness, Brightness.dark);
      });

      testWidgets('deepSpace theme properties', (WidgetTester tester) async {
        final theme = DadyTubeTheme.getTheme(AppThemeLevel.deepSpace);
        expect(theme.scaffoldBackgroundColor, const Color(0xFF0F0F0F));
        expect(theme.colorScheme.primary, const Color(0xFFE91E63));
        expect(theme.colorScheme.primaryContainer, const Color(0xFF1E1E1E));
        expect(theme.colorScheme.secondary, const Color(0xFFFFB8CD));
        expect(theme.colorScheme.surface, const Color(0xFF121212));
        expect(theme.colorScheme.onSurface, Colors.white);
        expect(theme.colorScheme.brightness, Brightness.dark);
      });
    });
  });
}
