import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/core/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  group('AppLocalizations', () {
    test('translates English correctly', () {
      final localizations = AppLocalizations(const Locale('en'));
      expect(localizations.translate('app_title'), 'DadyTube');
    });

    test('translates Arabic correctly', () {
      final localizations = AppLocalizations(const Locale('ar'));
      expect(localizations.translate('app_title'), 'دادي تيوب');
    });

    test('returns key if translation is not found', () {
      final localizations = AppLocalizations(const Locale('en'));
      expect(localizations.translate('unknown_key'), 'unknown_key');
    });

    test('replaces arguments in string', () {
      final localizations = AppLocalizations(const Locale('en'));
      expect(
        localizations.translate('splash_finding', args: {'name': 'Animals'}),
        'Finding Animals...',
      );

      final arabicLocalizations = AppLocalizations(const Locale('ar'));
      expect(
        arabicLocalizations.translate(
          'splash_finding',
          args: {'name': 'حيوانات'},
        ),
        'جاري البحث عن حيوانات...',
      );
    });

    testWidgets('AppLocalizations.of(context) retrieves correct instance', (
      WidgetTester tester,
    ) async {
      AppLocalizations? retrievedLocalizations;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              retrievedLocalizations = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // We need to wait for pump to complete the build cycle
      await tester.pumpAndSettle();

      expect(retrievedLocalizations, isNotNull);
      expect(retrievedLocalizations!.locale.languageCode, 'en');
      expect(retrievedLocalizations!.translate('app_title'), 'DadyTube');
    });
  });

  group('AppLocalizationsDelegate', () {
    const delegate = AppLocalizationsDelegate();

    test('isSupported returns true for supported locales', () {
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
}
