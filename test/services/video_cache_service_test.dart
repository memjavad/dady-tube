import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/services/video_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VideoCacheService Memory Cache Hit Path Test', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await VideoCacheService().clearAllCache();
    });

    test('getCachedStreamUrl returns instantly from memory without I/O', () async {
      final cacheService = VideoCacheService();
      final videoId = 'test_mem_video_id';
      final testUrl = 'https://example.com/stream.mp4';

      // Inject entry to memory cache by first relying on the fallback path.
      // We set SharedPreferences directly so the first call reads from disk,
      // which populates the in-memory cache `_streamUrlMemCache`.
      SharedPreferences.setMockInitialValues({
        'persistent_stream_urls':
            '{"$videoId":{"url":"$testUrl","timestamp":${DateTime.now().millisecondsSinceEpoch}}}',
      });

      // First call: reads from SharedPreferences (disk) and populates memory cache
      final diskHitUrl = await cacheService.getCachedStreamUrl(videoId);
      expect(diskHitUrl, equals(testUrl));

      // Now clear SharedPreferences to prove it's reading from memory
      SharedPreferences.setMockInitialValues({});

      // Second call: should hit memory and return the URL even without SharedPrefs data
      final memHitUrl = await cacheService.getCachedStreamUrl(videoId);
      expect(memHitUrl, equals(testUrl));
    });
  });
}
