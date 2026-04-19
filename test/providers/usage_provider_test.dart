import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:dadytube/providers/usage_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UsageProvider', () {
    test('initializes with default values when SharedPreferences is empty', () {
      fakeAsync((async) {
        SharedPreferences.setMockInitialValues({});

        final provider = UsageProvider();

        // Wait for _loadSettings future to complete
        async.flushMicrotasks();

        expect(provider.dailyLimitMinutes, 120);
        expect(provider.usageSeconds, 0);
        expect(provider.starsCount, 0);
        expect(provider.monthlyStars, 0);
        expect(provider.isBedtime, false);
        expect(provider.progress, 0.0);
        expect(provider.sunsetIntensity, 0.0);

        provider.dispose();
      });
    });
    test('initializes with existing SharedPreferences values', () {
      fakeAsync((async) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        final currentMonth = "${DateTime.now().year}-${DateTime.now().month}";

        SharedPreferences.setMockInitialValues({
          'daily_limit_minutes': 60,
          'daily_usage_seconds': 1800, // 30 minutes
          'magic_stars_count': 5,
          'monthly_stars_count': 10,
          'last_reset_date': today,
          'last_reset_month': currentMonth,
        });

        final provider = UsageProvider();

        // Wait for _loadSettings
        async.flushMicrotasks();

        expect(provider.dailyLimitMinutes, 60);
        expect(provider.usageSeconds, 1800);
        expect(provider.starsCount, 5);
        expect(provider.monthlyStars, 10);
        expect(provider.progress, 0.5); // 1800 / (60 * 60)

        provider.dispose();
      });
    });
    test('addStar increments stars and notifies listeners', () {
      fakeAsync((async) {
        SharedPreferences.setMockInitialValues({});
        final provider = UsageProvider();
        async.flushMicrotasks();

        bool notified = false;
        provider.addListener(() => notified = true);

        provider.addStar();
        async.flushMicrotasks(); // Wait for prefs.setInt inside addStar

        expect(provider.starsCount, 1);
        expect(notified, isTrue);

        provider.dispose();
      });
    });

    test(
      'setDailyLimit updates limit, resets bedtime, and notifies listeners',
      () {
        fakeAsync((async) {
          final today = DateTime.now().toIso8601String().split('T')[0];
          SharedPreferences.setMockInitialValues({
            'daily_usage_seconds': 7200,
            'last_reset_date': today,
          });
          final provider = UsageProvider();
          async.flushMicrotasks();

          expect(
            provider.isBedtime,
            isTrue,
          ); // Should be bedtime initially with 120min default

          bool notified = false;
          provider.addListener(() => notified = true);

          provider.setDailyLimit(180); // Increase limit to 3 hours
          async.flushMicrotasks();

          expect(provider.dailyLimitMinutes, 180);
          expect(provider.isBedtime, isFalse);
          expect(notified, isTrue);

          provider.dispose();
        });
      },
    );

    test('grantExtraTime subtracts usage and resets bedtime', () {
      fakeAsync((async) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        SharedPreferences.setMockInitialValues({
          'daily_usage_seconds': 7200,
          'last_reset_date': today,
        });
        final provider = UsageProvider();
        async.flushMicrotasks();

        expect(provider.isBedtime, isTrue);

        bool notified = false;
        provider.addListener(() => notified = true);

        provider.grantExtraTime(5); // Grant 5 mins (300 seconds)
        async.flushMicrotasks();

        expect(provider.usageSeconds, 6900); // 7200 - 300
        expect(provider.isBedtime, isFalse);
        expect(notified, isTrue);

        // Granting more time than used should cap at 0
        provider.grantExtraTime(200); // Grant 200 mins
        async.flushMicrotasks();
        expect(provider.usageSeconds, 0);

        provider.dispose();
      });
    });
    test('timer increments usageSeconds every second', () {
      fakeAsync((async) {
        SharedPreferences.setMockInitialValues({});
        final provider = UsageProvider();
        async.flushMicrotasks();

        expect(provider.usageSeconds, 0);

        // Elapse 5 seconds
        async.elapse(const Duration(seconds: 5));

        expect(provider.usageSeconds, 5);

        provider.dispose();
      });
    });
    test('timer pauses when app is paused and resumes when resumed', () {
      fakeAsync((async) {
        SharedPreferences.setMockInitialValues({});
        final provider = UsageProvider();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 2));
        expect(provider.usageSeconds, 2);

        // Pause app
        provider.didChangeAppLifecycleState(AppLifecycleState.paused);

        // Elapse time while paused
        async.elapse(const Duration(seconds: 5));

        // Usage should not have increased
        expect(provider.usageSeconds, 2);

        // Resume app
        provider.didChangeAppLifecycleState(AppLifecycleState.resumed);

        // Elapse time
        async.elapse(const Duration(seconds: 3));

        expect(provider.usageSeconds, 5); // 2 + 3

        provider.dispose();
      });
    });
    test('isBedtime triggers when usage reaches daily limit', () {
      fakeAsync((async) {
        SharedPreferences.setMockInitialValues({
          'daily_limit_minutes': 1,
        }); // 1 minute limit (60 seconds)
        final provider = UsageProvider();
        async.flushMicrotasks();

        expect(provider.isBedtime, isFalse);

        bool notified = false;
        provider.addListener(() => notified = true);

        // Progress to 59 seconds
        async.elapse(const Duration(seconds: 59));
        expect(provider.isBedtime, isFalse);
        expect(notified, isFalse);

        // Progress 1 more second to hit 60s
        async.elapse(const Duration(seconds: 1));

        expect(provider.usageSeconds, 60);
        expect(provider.isBedtime, isTrue);
        expect(notified, isTrue);

        provider.dispose();
      });
    });
    test('sunsetIntensity calculation', () {
      fakeAsync((async) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        // 60 mins limit = 3600 seconds
        // 55 mins used = 3300 seconds (300s remaining, start of fade)
        SharedPreferences.setMockInitialValues({
          'daily_limit_minutes': 60,
          'daily_usage_seconds': 3300,
          'last_reset_date': today,
        });
        final provider = UsageProvider();
        async.flushMicrotasks();

        // At exactly 300s remaining, intensity should be near 0.0
        // The formula is: (1.0 - (remaining / 300)).clamp(0, 1)
        expect(provider.sunsetIntensity, 0.0);

        // Progress 150 seconds (halfway through the 300s sunset period)
        async.elapse(const Duration(seconds: 150));

        // remaining = 150. intensity = 1.0 - (150/300) = 0.5
        expect(provider.sunsetIntensity, closeTo(0.5, 0.01));

        // Progress past the limit
        async.elapse(const Duration(seconds: 200));

        // remaining < 0, intensity = 1.0
        expect(provider.sunsetIntensity, 1.0);

        provider.dispose();
      });
    });

    test('daily reset calculates leftover stars and resets usage', () {
      fakeAsync((async) {
        // Mock a previous day
        final yesterday = DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String()
            .split('T')[0];

        SharedPreferences.setMockInitialValues({
          'daily_limit_minutes': 120, // 7200 seconds limit
          'daily_usage_seconds':
              3600, // 3600 seconds used yesterday, so 3600 left
          'monthly_stars_count': 5,
          'last_reset_date': yesterday,
          'last_reset_month': "${DateTime.now().year}-${DateTime.now().month}",
        });

        final provider = UsageProvider();
        async.flushMicrotasks();

        // 3600 leftover seconds / 3000 = 1 earned star
        // previous monthly stars = 5
        // total = 6

        expect(provider.usageSeconds, 0); // Usage reset to 0
        expect(provider.monthlyStars, 6); // Earned 1 star

        provider.dispose();
      });
    });

    test('monthly reset zeroes monthly stars', () {
      fakeAsync((async) {
        // Mock a previous month
        final lastMonthStr =
            "${DateTime.now().year}-${DateTime.now().month - 1}";

        SharedPreferences.setMockInitialValues({
          'monthly_stars_count': 50,
          'last_reset_month': lastMonthStr,
        });

        final provider = UsageProvider();
        async.flushMicrotasks();

        expect(provider.monthlyStars, 0); // Reset for the new month

        provider.dispose();
      });
    });
  });
}
