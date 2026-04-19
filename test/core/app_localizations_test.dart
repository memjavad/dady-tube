import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dadytube/core/app_localizations.dart';

void main() {
  group('AppLocalizations Tests', () {
    test('English translations', () {
      final localizations = AppLocalizations(const Locale('en'));

      // Basic translation
      expect(localizations.translate('app_title'), 'DadyTube');
      expect(localizations.translate('search_hint'), 'Search for fun!');

      // Interpolation translation
      expect(
        localizations.translate('plus_mins', args: {'min': '15'}),
        '+15 min',
      );

      // Missing translation
      expect(
        localizations.translate('missing_key_that_does_not_exist'),
        'missing_key_that_does_not_exist',
      );
    });

    test('Arabic translations', () {
      final localizations = AppLocalizations(const Locale('ar'));

      // Basic translation
      expect(localizations.translate('app_title'), 'دادي تيوب');
      expect(localizations.translate('search_hint'), 'ابحث عن المرح!');

      // Interpolation translation
      expect(
        localizations.translate('plus_mins', args: {'min': '15'}),
        '+15 دقيقة',
      );

      // Missing translation
      expect(
        localizations.translate('missing_key_that_does_not_exist'),
        'missing_key_that_does_not_exist',
      );
    });

    test('Unsupported locale fallback', () {
      final localizations = AppLocalizations(
        const Locale('fr'),
      ); // Not supported, but checking behavior

      // Should fallback to the key itself if _localizedValues doesn't contain the languageCode
      expect(localizations.translate('app_title'), 'app_title');
    });
  });

  group('AppLocalizationsDelegate Tests', () {
    const delegate = AppLocalizationsDelegate();

    test('isSupported', () {
      expect(delegate.isSupported(const Locale('en')), isTrue);
      expect(delegate.isSupported(const Locale('ar')), isTrue);
      expect(delegate.isSupported(const Locale('fr')), isFalse);
      expect(delegate.isSupported(const Locale('es')), isFalse);
    });

    test('load', () async {
      final localizations = await delegate.load(const Locale('en'));
      expect(localizations, isA<AppLocalizations>());
      expect(localizations.locale.languageCode, 'en');
    });

    test('shouldReload', () {
      expect(delegate.shouldReload(const AppLocalizationsDelegate()), isFalse);
    });
  });

  group('Widget context Tests', () {
    testWidgets('AppLocalizations.of(context) retrieves correct instance', (
      WidgetTester tester,
    ) async {
      late AppLocalizations retrievedLocalizations;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', ''), Locale('ar', '')],
          locale: const Locale('en'),
          home: Builder(
            builder: (BuildContext context) {
              retrievedLocalizations = AppLocalizations.of(context);
              return Scaffold(
                body: Text(retrievedLocalizations.translate('app_title')),
              );
            },
          ),
        ),
      );

      // Wait for localizations to load
      await tester.pumpAndSettle();

      expect(retrievedLocalizations.locale.languageCode, 'en');
      expect(find.text('DadyTube'), findsOneWidget);
    });
  });
}
