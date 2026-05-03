import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dadytube/providers/usage_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'last_reset_date': DateTime.now().toIso8601String().split('T')[0],
      'daily_usage_seconds': 0,
    });
  });

  testWidgets('UsageProvider pauses timer when app lifecycle state is paused, detached, or hidden', (WidgetTester tester) async {
    final provider = UsageProvider();

    // Wait for the provider to load settings
    await tester.pumpAndSettle();

    // Helper function to test a specific state pauses the timer
    Future<void> expectStatePausesTimer(AppLifecycleState state) async {
      provider.didChangeAppLifecycleState(state);
      final usageBefore = provider.usageSeconds;
      await tester.pump(const Duration(seconds: 2));
      expect(provider.usageSeconds, equals(usageBefore), reason: 'Timer should be paused for state $state');

      // Resume app
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      final usageAfterResume = provider.usageSeconds;
      await tester.pump(const Duration(seconds: 2));
      expect(provider.usageSeconds, greaterThan(usageAfterResume), reason: 'Timer should resume when state is resumed');
    }

    // Verify initial active state
    final initialUsage = provider.usageSeconds;
    await tester.pump(const Duration(seconds: 2));
    expect(provider.usageSeconds, greaterThan(initialUsage));

    // Test paused
    await expectStatePausesTimer(AppLifecycleState.paused);

    // Test detached
    await expectStatePausesTimer(AppLifecycleState.detached);

    // Test hidden
    await expectStatePausesTimer(AppLifecycleState.hidden);

    // Test inactive
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
    provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
    var usageBefore = provider.usageSeconds;
    await tester.pump(const Duration(seconds: 2));
    expect(provider.usageSeconds, greaterThan(usageBefore), reason: 'Timer should continue when state transitions from resumed to inactive');

    provider.didChangeAppLifecycleState(AppLifecycleState.paused);
    provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
    usageBefore = provider.usageSeconds;
    await tester.pump(const Duration(seconds: 2));
    expect(provider.usageSeconds, equals(usageBefore), reason: 'Timer should stay paused when state transitions from paused to inactive');

    provider.dispose();
  });
}
