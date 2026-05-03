import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dadytube/providers/settings_provider.dart';

void main() {
  test('Benchmark SettingsProvider setters', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = SettingsProvider();

    // Wait for initial load
    await Future.delayed(Duration(milliseconds: 100));

    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 10000; i++) {
      await provider.setFullScreenByDefault(i % 2 == 0);
    }
    stopwatch.stop();
    print('Time taken for 10000 setter calls: ${stopwatch.elapsedMilliseconds} ms');
  });
}
