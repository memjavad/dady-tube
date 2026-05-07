import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dadytube/providers/usage_provider.dart';
import 'package:flutter/widgets.dart';

void main() {
  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    final today = DateTime.now().toIso8601String().split('T')[0];
    SharedPreferences.setMockInitialValues({
      'daily_usage_seconds': 3600, // 1 hour
      'daily_limit_minutes': 120, // 2 hours
      'last_reset_date': today,
    });
  });

  test(
    'grantExtraTime correctly subtracts granted time from recorded usage',
    () async {
      final provider = UsageProvider();
      // Wait for async init to complete
      await Future.delayed(Duration.zero);

      expect(provider.usageSeconds, 3600);

      // Grant 5 extra minutes
      provider.grantExtraTime(5);

      // Usage should be 3600 - (5 * 60) = 3300
      expect(provider.usageSeconds, 3300);
      expect(provider.isBedtime, false);
    },
  );

  test(
    'grantExtraTime caps usage at 0 when granting more time than used',
    () async {
      final provider = UsageProvider();
      await Future.delayed(Duration.zero);

      // Usage is 3600. Grant 100 minutes (6000 seconds)
      provider.grantExtraTime(100);

      // Usage should not be negative
      expect(provider.usageSeconds, 0);
    },
  );
}
