import 'dart:io';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:dadytube/services/video_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sanitize ID handles dangerous characters', () {
    final service = VideoCacheService();
    expect(service.sanitizeVideoId('abc-123_XYZ!@#'), 'abc-123_XYZ___');
  });

  test('Stream URL memory cache reads from SharedPrefs only once', () async {
    final validFutureTimestamp = DateTime.now().millisecondsSinceEpoch;
    // Add expire query param far in the future to pass _isUrlExpired check
    final expireSeconds =
        (DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/
                1000)
            .toString();
    final validUrl = 'http://example.com/video?expire=$expireSeconds';
    final videoId = 'test_video_id_${DateTime.now().millisecondsSinceEpoch}';

    final mockData = {
      videoId: {'url': validUrl, 'timestamp': validFutureTimestamp},
    };

    SharedPreferences.setMockInitialValues({
      'persistent_stream_urls': json.encode(mockData),
    });

    final prefs = await SharedPreferences.getInstance();
    await Future.delayed(Duration.zero);

    final service = VideoCacheService();

    // 1st Read: Should read from SharedPrefs and populate _streamUrlMemCache
    final firstReadUrl = await service.getCachedStreamUrl(videoId);
    expect(
      firstReadUrl,
      validUrl,
      reason: 'First read should retrieve the URL from SharedPrefs',
    );

    // Clear SharedPreferences to prove disk is not accessed again
    await prefs.remove('persistent_stream_urls');

    // 2nd Read: Should read from _streamUrlMemCache
    final secondReadUrl = await service.getCachedStreamUrl(videoId);
    expect(
      secondReadUrl,
      validUrl,
      reason: 'Second read should retrieve the URL from memory cache',
    );
  });
}
