import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';

enum VideoQuality { auto, p360, p720, p1080 }

class SettingsProvider with ChangeNotifier {
  VideoQuality _videoQuality = VideoQuality.auto;
  bool _fullScreenByDefault = false;
  bool _showSuggestions = false;
  bool _autoCacheEnabled = true;
  bool _bedtimeMode = false;
  bool _eyeProtectionEnabled = true;
  bool _restRemindersEnabled = true;
  bool _distanceProtectionEnabled = true;
  List<String> _blockedKeywords = [];
  Locale _locale = const Locale('en', 'US');
  AppThemeLevel _themeLevel = AppThemeLevel.blush;
  bool _turboModeEnabled = true;
  bool _postureProtectionEnabled = true;
  bool _safeVolumeEnabled = true;
  double _maxVolumeLevel = 0.5;

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _getPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  VideoQuality get videoQuality => _videoQuality;
  bool get fullScreenByDefault => _fullScreenByDefault;
  bool get showSuggestions => _showSuggestions;
  bool get autoCacheEnabled => _autoCacheEnabled;
  bool get bedtimeMode => _bedtimeMode;
  bool get eyeProtectionEnabled => _eyeProtectionEnabled;
  bool get restRemindersEnabled => _restRemindersEnabled;
  bool get distanceProtectionEnabled => _distanceProtectionEnabled;
  bool get turboModeEnabled => _turboModeEnabled;
  bool get postureProtectionEnabled => _postureProtectionEnabled;
  bool get safeVolumeEnabled => _safeVolumeEnabled;
  double get maxVolumeLevel => _maxVolumeLevel;
  List<String> get blockedKeywords => _blockedKeywords;
  Locale get locale => _locale;
  AppThemeLevel get themeLevel => _themeLevel;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await _getPrefs;
    final qualityIndex =
        prefs.getInt('video_quality') ?? VideoQuality.auto.index;
    _videoQuality = VideoQuality.values[qualityIndex];
    _fullScreenByDefault = prefs.getBool('full_screen_by_default') ?? false;
    _showSuggestions = prefs.getBool('show_suggestions') ?? false;
    _autoCacheEnabled = prefs.getBool('auto_cache_enabled') ?? true;
    _bedtimeMode = prefs.getBool('bedtimeMode') ?? false;
    _eyeProtectionEnabled = prefs.getBool('eyeProtectionEnabled') ?? true;
    _restRemindersEnabled = prefs.getBool('restRemindersEnabled') ?? true;
    _distanceProtectionEnabled =
        prefs.getBool('distanceProtectionEnabled') ?? true;
    _turboModeEnabled = prefs.getBool('turbo_mode_enabled') ?? true;
    _blockedKeywords = prefs.getStringList('blocked_keywords') ?? [];

    _postureProtectionEnabled =
        prefs.getBool('postureProtectionEnabled') ?? true;
    _safeVolumeEnabled = prefs.getBool('safeVolumeEnabled') ?? true;
    _maxVolumeLevel = prefs.getDouble('maxVolumeLevel') ?? 0.5;

    final langCode = prefs.getString('language_code') ?? 'en';
    final countryCode = prefs.getString('country_code') ?? 'US';
    _locale = Locale(langCode, countryCode);

    final levelIndex = prefs.getInt('theme_level') ?? AppThemeLevel.blush.index;
    _themeLevel = AppThemeLevel.values[levelIndex];

    notifyListeners();
  }

  Future<void> setVideoQuality(VideoQuality quality) async {
    _videoQuality = quality;
    final prefs = await _getPrefs;
    await prefs.setInt('video_quality', quality.index);
    notifyListeners();
  }

  bool get isNightTime {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 6; // 7 PM to 6 AM
  }

  double get blueLightIntensity {
    if (!_eyeProtectionEnabled) return 0.0;

    final hour = DateTime.now().hour;
    if (hour >= 21 || hour < 6) {
      return 0.32; // Maximum protection late at night
    } else if (hour >= 19) {
      return 0.22; // Medium protection in the evening
    } else {
      return 0.12; // Light protection during the day
    }
  }

  Future<void> setFullScreenByDefault(bool value) async {
    _fullScreenByDefault = value;
    final prefs = await _getPrefs;
    await prefs.setBool('full_screen_by_default', value);
    notifyListeners();
  }

  Future<void> setShowSuggestions(bool value) async {
    _showSuggestions = value;
    final prefs = await _getPrefs;
    await prefs.setBool('show_suggestions', value);
    notifyListeners();
  }

  Future<void> setAutoCacheEnabled(bool value) async {
    _autoCacheEnabled = value;
    final prefs = await _getPrefs;
    await prefs.setBool('auto_cache_enabled', value);
    notifyListeners();
  }

  Future<void> setBedtimeMode(bool value) async {
    _bedtimeMode = value;
    final prefs = await _getPrefs;
    await prefs.setBool('bedtimeMode', value);
    notifyListeners();
  }

  Future<void> setEyeProtection(bool value) async {
    _eyeProtectionEnabled = value;
    final prefs = await _getPrefs;
    await prefs.setBool('eyeProtectionEnabled', value);
    notifyListeners();
  }

  Future<void> setRestReminders(bool value) async {
    _restRemindersEnabled = value;
    final prefs = await _getPrefs;
    await prefs.setBool('restRemindersEnabled', value);
    notifyListeners();
  }

  Future<void> setDistanceProtection(bool value) async {
    _distanceProtectionEnabled = value;
    final prefs = await _getPrefs;
    await prefs.setBool('distanceProtectionEnabled', value);
    notifyListeners();
  }

  Future<void> setTurboMode(bool value) async {
    _turboModeEnabled = value;
    final prefs = await _getPrefs;
    await prefs.setBool('turbo_mode_enabled', value);
    notifyListeners();
  }

  Future<void> addBlockedKeyword(String keyword) async {
    final trimmed = keyword.trim().toLowerCase();
    if (trimmed.isNotEmpty && !_blockedKeywords.contains(trimmed)) {
      _blockedKeywords.add(trimmed);
      final prefs = await _getPrefs;
      await prefs.setStringList('blocked_keywords', _blockedKeywords);
      notifyListeners();
    }
  }

  Future<void> removeBlockedKeyword(String keyword) async {
    if (_blockedKeywords.contains(keyword)) {
      _blockedKeywords.remove(keyword);
      final prefs = await _getPrefs;
      await prefs.setStringList('blocked_keywords', _blockedKeywords);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await _getPrefs;
    await prefs.setString('language_code', locale.languageCode);
    await prefs.setString('country_code', locale.countryCode ?? '');
    notifyListeners();
  }

  Future<void> setPostureProtection(bool value) async {
    _postureProtectionEnabled = value;
    final prefs = await _getPrefs;
    await prefs.setBool('postureProtectionEnabled', value);
    notifyListeners();
  }

  Future<void> setSafeVolumeEnabled(bool value) async {
    _safeVolumeEnabled = value;
    final prefs = await _getPrefs;
    await prefs.setBool('safeVolumeEnabled', value);
    notifyListeners();
  }

  Future<void> setMaxVolumeLevel(double value) async {
    _maxVolumeLevel = value;
    final prefs = await _getPrefs;
    await prefs.setDouble('maxVolumeLevel', value);
    notifyListeners();
  }

  Future<void> setThemeLevel(AppThemeLevel level) async {
    _themeLevel = level;
    final prefs = await _getPrefs;
    await prefs.setInt('theme_level', level.index);
    notifyListeners();
  }
}
