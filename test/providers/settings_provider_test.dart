import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dadytube/providers/settings_provider.dart';
import 'package:dadytube/core/theme.dart';
import 'package:flutter/material.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsProvider', () {
    test('initializes with default values when SharedPreferences is empty', () async {
      final provider = SettingsProvider();

      // Since _loadSettings is async and called in the constructor,
      // we need to wait for a microtask to allow the async load to complete.
      await Future.delayed(Duration.zero);

      expect(provider.videoQuality, VideoQuality.auto);
      expect(provider.fullScreenByDefault, false);
      expect(provider.showSuggestions, false);
      expect(provider.autoCacheEnabled, true);
      expect(provider.bedtimeMode, false);
      expect(provider.eyeProtectionEnabled, true);
      expect(provider.restRemindersEnabled, true);
      expect(provider.distanceProtectionEnabled, true);
      expect(provider.turboModeEnabled, true);
      expect(provider.postureProtectionEnabled, true);
      expect(provider.safeVolumeEnabled, true);
      expect(provider.maxVolumeLevel, 0.5);
      expect(provider.blockedKeywords, isEmpty);
      expect(provider.locale, const Locale('en', 'US'));
      expect(provider.themeLevel, AppThemeLevel.blush);
    });

    test('initializes with values from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'video_quality': VideoQuality.p720.index,
        'full_screen_by_default': true,
        'show_suggestions': true,
        'auto_cache_enabled': false,
        'bedtimeMode': true,
        'eyeProtectionEnabled': false,
        'restRemindersEnabled': false,
        'distanceProtectionEnabled': false,
        'turbo_mode_enabled': false,
        'postureProtectionEnabled': false,
        'safeVolumeEnabled': false,
        'maxVolumeLevel': 0.8,
        'blocked_keywords': ['test', 'word'],
        'language_code': 'es',
        'country_code': 'ES',
        'theme_level': AppThemeLevel.midnight.index,
      });

      final provider = SettingsProvider();
      await Future.delayed(Duration.zero);

      expect(provider.videoQuality, VideoQuality.p720);
      expect(provider.fullScreenByDefault, true);
      expect(provider.showSuggestions, true);
      expect(provider.autoCacheEnabled, false);
      expect(provider.bedtimeMode, true);
      expect(provider.eyeProtectionEnabled, false);
      expect(provider.restRemindersEnabled, false);
      expect(provider.distanceProtectionEnabled, false);
      expect(provider.turboModeEnabled, false);
      expect(provider.postureProtectionEnabled, false);
      expect(provider.safeVolumeEnabled, false);
      expect(provider.maxVolumeLevel, 0.8);
      expect(provider.blockedKeywords, ['test', 'word']);
      expect(provider.locale, const Locale('es', 'ES'));
      expect(provider.themeLevel, AppThemeLevel.midnight);
    });

    test('setters update value and persist to SharedPreferences', () async {
      final provider = SettingsProvider();
      await Future.delayed(Duration.zero);

      await provider.setVideoQuality(VideoQuality.p1080);
      expect(provider.videoQuality, VideoQuality.p1080);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('video_quality'), VideoQuality.p1080.index);

      await provider.setFullScreenByDefault(true);
      expect(provider.fullScreenByDefault, true);
      expect(prefs.getBool('full_screen_by_default'), true);

      await provider.addBlockedKeyword('badword');
      expect(provider.blockedKeywords, contains('badword'));
      expect(prefs.getStringList('blocked_keywords'), contains('badword'));

      await provider.removeBlockedKeyword('badword');
      expect(provider.blockedKeywords, isNot(contains('badword')));
      expect(prefs.getStringList('blocked_keywords'), isNot(contains('badword')));
    });

    test('isNightTime returns correct value based on current hour', () {
      final provider = SettingsProvider();
      final now = DateTime.now().hour;
      final expected = now >= 19 || now < 6;
      expect(provider.isNightTime, expected);
    });
  });
}
