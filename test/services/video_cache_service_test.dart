import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dadytube/services/video_cache_service.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('getCachedStreamUrl checks in-memory cache first - zero disk I/O', () async {
    final videoId = 'test_video_123';
    final futureTime = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600; // 1 hour in future
    final url = 'https://example.com/stream?expire=$futureTime';
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    SharedPreferences.setMockInitialValues({
      'persistent_stream_urls': json.encode({
        videoId: {
          'url': url,
          'timestamp': timestamp,
        }
      })
    });

    // We need to wait for SharedPreferences to initialize
    await Future.delayed(Duration.zero);

    final service = VideoCacheService();

    // 1. First call should fetch from disk (SharedPreferences) and populate memory cache
    final firstResult = await service.getCachedStreamUrl(videoId);
    expect(firstResult, url);

    // 2. Clear SharedPreferences to simulate that it should NOT be read anymore
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 3. Second call should hit memory cache and return the URL
    // Proving zero disk I/O fallback since disk is now empty
    final secondResult = await service.getCachedStreamUrl(videoId);
    expect(secondResult, url);
  });
}
