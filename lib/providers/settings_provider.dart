import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../core/theme.dart';

enum VideoQuality { auto, p360, p720, p1080 }

class SettingsProvider with ChangeNotifier {
  SharedPreferences? _prefs;
  // ⚡ Bolt: Lazy SharedPreferences caching to avoid redundant disk lookups
  Future<SharedPreferences> get _getPrefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  VideoQuality _videoQuality = VideoQuality.auto;
  bool _isFirstRun = true;

  bool get isFirstRun => _isFirstRun;

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
  String? _masterPin;
  bool _smartNightSyncEnabled = true;
  int _smartNightSyncHour = 3; // Default 3 AM
  int _smartNightSyncVideoLimit = 2; // Default 2 videos per channel

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
  String? get masterPin => _masterPin;
  bool get hasMasterPin => _masterPin != null && _masterPin!.isNotEmpty;
  bool get smartNightSyncEnabled => _smartNightSyncEnabled;
  int get smartNightSyncHour => _smartNightSyncHour;
  int get smartNightSyncVideoLimit => _smartNightSyncVideoLimit;

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
    _isFirstRun = prefs.getBool('is_first_run') ?? true;
    _masterPin = prefs.getString('master_pin');
    _smartNightSyncEnabled = prefs.getBool('smart_night_sync_enabled') ?? true;
    _smartNightSyncHour = prefs.getInt('smart_night_sync_hour') ?? 3;
    _smartNightSyncVideoLimit = prefs.getInt('smart_night_sync_video_limit') ?? 2;
    
    // Auto-schedule on load if enabled
    if (_smartNightSyncEnabled) {
      _scheduleNightlySync();
    }

    final savedLangCode = prefs.getString('language_code');
    final savedCountryCode = prefs.getString('country_code');
    if (savedLangCode != null && savedLangCode.isNotEmpty) {
      _locale = Locale(savedLangCode, savedCountryCode ?? '');
    } else {
      final deviceLocale = ui.PlatformDispatcher.instance.locale;
      _locale = deviceLocale.languageCode == 'ar'
          ? const Locale('ar', 'IQ')
          : const Locale('en', 'US');
    }

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

  Future<void> completeOnboarding() async {
    _isFirstRun = false;
    final prefs = await _getPrefs;
    await prefs.setBool('is_first_run', false);
    notifyListeners();
  }

  Future<void> setMasterPin(String? pin) async {
    _masterPin = pin;
    final prefs = await _getPrefs;
    if (pin != null && pin.isNotEmpty) {
      await prefs.setString('master_pin', pin);
    } else {
      await prefs.remove('master_pin');
    }
    notifyListeners();
  }

  bool verifyMasterPin(String input) {
    if (!hasMasterPin) return false;
    return _masterPin == input;
  }

  Future<void> setSmartNightSyncEnabled(bool enabled) async {
    _smartNightSyncEnabled = enabled;
    final prefs = await _getPrefs;
    await prefs.setBool('smart_night_sync_enabled', enabled);
    if (enabled) {
      _scheduleNightlySync();
    } else {
      _cancelNightlySync();
    }
    notifyListeners();
  }

  Future<void> setSmartNightSyncHour(int hour) async {
    _smartNightSyncHour = hour;
    final prefs = await _getPrefs;
    await prefs.setInt('smart_night_sync_hour', hour);
    if (_smartNightSyncEnabled) {
      // Re-schedule dynamically to apply new timing immediately
      _scheduleNightlySync();
    }
    notifyListeners();
  }

  Future<void> setSmartNightSyncVideoLimit(int limit) async {
    _smartNightSyncVideoLimit = limit;
    final prefs = await _getPrefs;
    await prefs.setInt('smart_night_sync_video_limit', limit);
    if (_smartNightSyncEnabled) {
      // Re-schedule dynamically to apply new limit to inputData immediately
      _scheduleNightlySync();
    }
    notifyListeners();
  }

  Duration _calculateDelayToHour(int hour) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled.difference(now);
  }

  void _scheduleNightlySync() {
    try {
      // Cancel existing first to prevent conflicts during rescheduling
      Workmanager().cancelByUniqueName('nightly_caching_sync');

      Workmanager().registerPeriodicTask(
        'nightly_caching_sync',
        'nightlySyncTask',
        frequency: const Duration(hours: 24),
        initialDelay: _calculateDelayToHour(_smartNightSyncHour),
        inputData: {
          'videoLimit': _smartNightSyncVideoLimit,
        },
        constraints: Constraints(
          networkType: NetworkType.unmetered, // WiFi only
        ),
      );
      debugPrint('🌙 DadyTube: Scheduled periodic nightly sync at $_smartNightSyncHour:00 constraints (WiFi only, limit: $_smartNightSyncVideoLimit)');
    } catch (e) {
      debugPrint('⚠️ Error registering WorkManager periodic task: $e');
    }
  }

  void _cancelNightlySync() {
    try {
      Workmanager().cancelByUniqueName('nightly_caching_sync');
      debugPrint('🌙 DadyTube: Cancelled periodic nightly sync.');
    } catch (e) {
      debugPrint('⚠️ Error cancelling WorkManager task: $e');
    }
  }
}
