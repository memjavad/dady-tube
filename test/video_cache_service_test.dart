import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dadytube/services/video_cache_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await VideoCacheService().clearAllCache();
  });

  tearDown(() async {
    await VideoCacheService().clearAllCache();
  });

  group('getCachedStreamUrl', () {
    test('returns null when cache is empty', () async {
      final service = VideoCacheService();
      final url = await service.getCachedStreamUrl('empty_video');
      expect(url, isNull);
    });

    test('returns URL from memory cache if present and not expired', () async {
      final service = VideoCacheService();
      final mockUrl = 'https://example.com/video?expire=2000000000';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('persistent_stream_urls', json.encode({
        'mem_video': {
          'url': mockUrl,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      }));

      // First call reads from disk and populates memory cache
      final url1 = await service.getCachedStreamUrl('mem_video');
      expect(url1, equals(mockUrl));

      // Clear shared prefs to ensure next call reads from memory cache
      await prefs.clear();

      // Second call reads from memory cache
      final url2 = await service.getCachedStreamUrl('mem_video');
      expect(url2, equals(mockUrl));
    });

    test('returns URL from disk cache if not in memory but valid', () async {
      final service = VideoCacheService();
      final mockUrl = 'https://example.com/video?expire=2000000000';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('persistent_stream_urls', json.encode({
        'disk_video': {
          'url': mockUrl,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      }));

      final url = await service.getCachedStreamUrl('disk_video');
      expect(url, equals(mockUrl));
    });

    test('returns null if URL is expired based on query param', () async {
      final service = VideoCacheService();
      // expire=1 represents Jan 1 1970
      final mockUrl = 'https://example.com/video?expire=1';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('persistent_stream_urls', json.encode({
        'expired_video': {
          'url': mockUrl,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      }));

      final url = await service.getCachedStreamUrl('expired_video');
      expect(url, isNull);
    });

    test('returns null if disk cache timestamp is older than 5 hours', () async {
      final service = VideoCacheService();
      final mockUrl = 'https://example.com/video?expire=2000000000';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('persistent_stream_urls', json.encode({
        'old_video': {
          'url': mockUrl,
          // 6 hours ago
          'timestamp': DateTime.now().subtract(const Duration(hours: 6)).millisecondsSinceEpoch,
        }
      }));

      final url = await service.getCachedStreamUrl('old_video');
      expect(url, isNull);
    });

    test('returns null if URL is expired based on path segment', () async {
      final service = VideoCacheService();
      // expire segment with timestamp 1 (Jan 1 1970)
      final mockUrl = 'https://example.com/video/expire/1/other/path';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('persistent_stream_urls', json.encode({
        'expired_path_video': {
          'url': mockUrl,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      }));

      final url = await service.getCachedStreamUrl('expired_path_video');
      expect(url, isNull);
    });

    test('returns URL from memory cache when disk cache clears', () async {
      final service = VideoCacheService();
      final mockUrl = 'https://example.com/video?expire=2000000000';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('persistent_stream_urls', json.encode({
        'persist_mem_video': {
          'url': mockUrl,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      }));

      // Cache it in memory
      await service.getCachedStreamUrl('persist_mem_video');

      // Clear the disk cache
      await prefs.clear();

      // Ensure it can still be fetched from memory
      final url = await service.getCachedStreamUrl('persist_mem_video');
      expect(url, equals(mockUrl));
    });
  });
}
