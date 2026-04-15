import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dadytube/core/app_localizations.dart';

void main() {
  group('AppLocalizationsDelegate', () {
    const delegate = AppLocalizationsDelegate();

    test('isSupported returns true for en and ar', () {
      expect(delegate.isSupported(const Locale('en')), isTrue);
      expect(delegate.isSupported(const Locale('ar')), isTrue);
    });

    test('isSupported returns false for unsupported locales', () {
      expect(delegate.isSupported(const Locale('fr')), isFalse);
      expect(delegate.isSupported(const Locale('es')), isFalse);
    });

    test('load returns an AppLocalizations instance', () async {
      final localizations = await delegate.load(const Locale('en'));
      expect(localizations, isA<AppLocalizations>());
      expect(localizations.locale.languageCode, 'en');
    });

    test('shouldReload returns false', () {
      expect(delegate.shouldReload(const AppLocalizationsDelegate()), isFalse);
    });
  });

  group('AppLocalizations.translate', () {
    test('translates English strings correctly', () {
      final localizations = AppLocalizations(const Locale('en'));
      expect(localizations.translate('app_title'), 'DadyTube');
      expect(localizations.translate('search_hint'), 'Search for fun!');
    });

    test('translates Arabic strings correctly', () {
      final localizations = AppLocalizations(const Locale('ar'));
      expect(localizations.translate('app_title'), 'دادي تيوب');
      expect(localizations.translate('search_hint'), 'ابحث عن المرح!');
    });

    test('returns key if translation is missing', () {
      final localizations = AppLocalizations(const Locale('en'));
      expect(localizations.translate('non_existent_key'), 'non_existent_key');
    });

    test('replaces placeholders correctly', () {
      final localizations = AppLocalizations(const Locale('en'));
      final translated = localizations.translate(
        'splash_finding',
        args: {'name': 'Animals'},
      );
      expect(translated, 'Finding Animals...');
    });

    test('replaces placeholders correctly for Arabic', () {
      final localizations = AppLocalizations(const Locale('ar'));
      final translated = localizations.translate(
        'splash_finding',
        args: {'name': 'حيوانات'},
      );
      expect(translated, 'جاري البحث عن حيوانات...');
    });
  });

  group('AppLocalizations.of', () {
    testWidgets('retrieves AppLocalizations from context', (
      WidgetTester tester,
    ) async {
      late AppLocalizations localizations;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              localizations = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(localizations, isNotNull);
      expect(localizations.locale.languageCode, 'en');
      expect(localizations.translate('app_title'), 'DadyTube');
    });
  });
}
