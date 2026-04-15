import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsageProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const String _keyLimit = 'daily_limit_minutes';
  static const String _keyUsage = 'daily_usage_seconds';
  static const String _keyLastReset = 'last_reset_date';
  static const String _keyStars = 'magic_stars_count';
  static const String _keyMonthlyStars = 'monthly_stars_count';
  static const String _keyLastAwardDate = 'last_award_date';

  int _dailyLimitMinutes = 120;
  int _usageSeconds = 0;
  int _starsCount = 0;
  int _monthlyStars = 0;
  Timer? _timer;
  bool _isBedtime = false;
  bool _isAppPaused = false;

  UsageProvider() {
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
      _isAppPaused = true;
    } else if (state == AppLifecycleState.resumed) {
      _isAppPaused = false;
    }
  }

  int get dailyLimitMinutes => _dailyLimitMinutes;
  int get usageSeconds => _usageSeconds;
  int get starsCount => _starsCount;
  int get monthlyStars => _monthlyStars;
  bool get isBedtime => _isBedtime;

  double get progress =>
      (_usageSeconds / (_dailyLimitMinutes * 60)).clamp(0.0, 1.0);

  double get sunsetIntensity {
    final limitSeconds = _dailyLimitMinutes * 60;
    final remainingSeconds = limitSeconds - _usageSeconds;
    // Start fading in the last 5 minutes (300 seconds)
    if (remainingSeconds <= 300 && remainingSeconds > 0) {
      return (1.0 - (remainingSeconds / 300)).clamp(0.0, 1.0);
    } else if (remainingSeconds <= 0) {
      return 1.0;
    }
    return 0.0;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastReset = prefs.getString(_keyLastReset) ?? '';

    // Check for monthly reset
    final lastMonth = prefs.getString('last_reset_month') ?? '';
    final currentMonth = "${DateTime.now().year}-${DateTime.now().month}";

    if (currentMonth != lastMonth) {
      _monthlyStars = 0;
      await prefs.setInt(_keyMonthlyStars, 0);
      await prefs.setString('last_reset_month', currentMonth);
    } else {
      _monthlyStars = prefs.getInt(_keyMonthlyStars) ?? 0;
    }

    if (today != lastReset) {
      // Award stars for yesterday's leftover time before resetting
      if (lastReset.isNotEmpty) {
        await _checkAndAwardLeftoverStars(prefs);
      }

      await prefs.setString(_keyLastReset, today);
      await prefs.setInt(_keyUsage, 0);
      _usageSeconds = 0;
    } else {
      _usageSeconds = prefs.getInt(_keyUsage) ?? 0;
    }

    _dailyLimitMinutes = prefs.getInt(_keyLimit) ?? 120;
    _starsCount = prefs.getInt(_keyStars) ?? 0;
    _checkBedtime();
    notifyListeners();
  }

  Future<void> _checkAndAwardLeftoverStars(SharedPreferences prefs) async {
    final lastUsage = prefs.getInt(_keyUsage) ?? 0;
    final lastLimit = prefs.getInt(_keyLimit) ?? 120;
    final limitSeconds = lastLimit * 60;
    final leftoverSeconds = limitSeconds - lastUsage;

    if (leftoverSeconds > 0) {
      // 50 minutes = 3000 seconds
      final earnedStars = (leftoverSeconds / 3000).floor();
      if (earnedStars > 0) {
        _monthlyStars += earnedStars;
        await prefs.setInt(_keyMonthlyStars, _monthlyStars);
      }
    }
  }

  void addStar() async {
    _starsCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStars, _starsCount);
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isBedtime && !_isAppPaused) {
        _usageSeconds++;
        if (_usageSeconds % 10 == 0) {
          // Save every 10 seconds
          _saveUsage();
        }
        _checkBedtime();
      }
    });
  }

  void _checkBedtime() {
    final limitSeconds = _dailyLimitMinutes * 60;
    if (_usageSeconds >= limitSeconds && !_isBedtime) {
      _isBedtime = true;
      notifyListeners();
    }
  }

  Future<void> _saveUsage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUsage, _usageSeconds);
  }

  Future<void> setDailyLimit(int minutes) async {
    _dailyLimitMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLimit, minutes);
    _isBedtime = false; // Reset bedtime state when limit changes
    _checkBedtime();
    notifyListeners();
  }

  // Parents can grant "5 more minutes"
  void grantExtraTime(int minutes) {
    // Audit Fix: Previously set usage to (limit - minutes) which is inverted.
    // Now correctly SUBTRACTS granted time from recorded usage.
    _usageSeconds -= minutes * 60;
    if (_usageSeconds < 0) _usageSeconds = 0;
    _isBedtime = false;
    _saveUsage();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}
