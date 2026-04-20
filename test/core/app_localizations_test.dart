import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/core/app_localizations.dart';

void main() {
  group('AppLocalizations', () {
    test('translate returns english value for english locale', () {
      final localizations = AppLocalizations(const Locale('en', 'US'));
      expect(localizations.translate('app_title'), 'DadyTube');
    });

    test('translate returns arabic value for arabic locale', () {
      final localizations = AppLocalizations(const Locale('ar', 'IQ'));
      expect(localizations.translate('app_title'), 'دادي تيوب');
    });

    test('translate falls back to key when key is not found', () {
      final localizations = AppLocalizations(const Locale('en', 'US'));
      expect(localizations.translate('non_existent_key_123'), 'non_existent_key_123');
    });

    test('translate falls back to key for unsupported locale', () {
      final localizations = AppLocalizations(const Locale('fr', 'FR'));
      expect(localizations.translate('non_existent_key'), 'non_existent_key');
    });

    test('translate replaces single argument', () {
      final localizations = AppLocalizations(const Locale('en', 'US'));
      expect(
        localizations.translate('splash_finding', args: {'name': 'Animals'}),
        'Finding Animals...',
      );
    });

    test('translate ignores unused arguments', () {
      final localizations = AppLocalizations(const Locale('en', 'US'));
      expect(
        localizations.translate('splash_finding', args: {'name': 'Animals', 'unused': 'xyz'}),
        'Finding Animals...',
      );
    });

    test('translate leaves template string if argument not provided', () {
      final localizations = AppLocalizations(const Locale('en', 'US'));
      expect(
        localizations.translate('splash_finding', args: {}),
        'Finding {name}...',
      );
    });

    test('translate handles multiple arguments using fallback string', () {
      final localizations = AppLocalizations(const Locale('en', 'US'));
      // Using a non-existent key that acts as a template to test multi-arg replacement
      expect(
        localizations.translate('test_{arg1}_{arg2}', args: {'arg1': 'foo', 'arg2': 'bar'}),
        'test_foo_bar',
      );
    });
  });

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

    test('load returns an instance of AppLocalizations', () async {
      final localizations = await delegate.load(const Locale('en'));
      expect(localizations, isA<AppLocalizations>());
      expect(localizations.locale.languageCode, 'en');
    });

    test('shouldReload always returns false', () {
      expect(delegate.shouldReload(const AppLocalizationsDelegate()), isFalse);
    });
  });
}
