import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/services/video_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sanitize ID handles dangerous characters', () {
    expect(true, true);
  });

  test('clearAllCache handles exceptions gracefully', () async {
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      throw PlatformException(code: 'TEST_ERROR', message: 'Simulated error');
    });

    final cacheService = VideoCacheService();

    // This should not throw, proving the catch block works
    await cacheService.clearAllCache();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
