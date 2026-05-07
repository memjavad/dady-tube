import 'dart:io';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/services/video_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String path;
  FakePathProviderPlatform(this.path);

  @override
  Future<String?> getTemporaryPath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class MockStreamManifest extends Mock implements yt.StreamManifest {
  @override
  UnmodifiableListView<yt.MuxedStreamInfo> get muxed => UnmodifiableListView([MockMuxedStreamInfo()]);
}

class MockMuxedStreamInfo extends Mock implements yt.MuxedStreamInfo {
  @override
  Uri get url => Uri.parse('https://example.com/video.mp4');
  @override
  yt.FileSize get size => yt.FileSize(1024);
  @override
  yt.Bitrate get bitrate => yt.Bitrate(1000);
}

class MockVideoClient extends Mock implements yt.VideoClient {
  @override
  yt.StreamClient get streamsClient => MockStreamClient();
}

class MockStreamClient extends Mock implements yt.StreamClient {
  static int getManifestCallCount = 0;
  static bool shouldThrow = false;

  @override
  Future<yt.StreamManifest> getManifest(dynamic videoId, {bool fullManifest = false, List<yt.YoutubeApiClient>? ytClients, bool requireWatchPage = false}) async {
    getManifestCallCount++;
    if (shouldThrow) {
      throw const SocketException('Simulated network error');
    }
    return MockStreamManifest();
  }
}

class MockYoutubeExplode extends Mock implements yt.YoutubeExplode {
  @override
  yt.VideoClient get videos => MockVideoClient();

  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late VideoCacheService service;
  late MockYoutubeExplode mockYtClient;
  late MockClient mockHttpClient;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('video_cache_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
    
    mockYtClient = MockYoutubeExplode();
    mockHttpClient = MockClient((request) async {
      return http.Response('dummy content chunk', 200);
    });

    service = VideoCacheService();
    service.mockYt = mockYtClient;
    service.mockHttpClient = mockHttpClient;
    
    MockStreamClient.getManifestCallCount = 0;
    MockStreamClient.shouldThrow = false;
    
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Video Download and Storage Tests', () {
    test('cacheVideo uses in-memory manifest and writes metadata sidecar', () async {
      await service.getManifest('test_video');
      expect(MockStreamClient.getManifestCallCount, 1);

      await service.cacheVideo(
        'test_video',
        title: 'Test Title',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        channelId: 'test_channel',
      );

      final metaFile = File('${tempDir.path}/video_cache/test_video.meta');
      expect(await metaFile.exists(), isTrue);

      final metaContent = await metaFile.readAsString();
      final metaData = json.decode(metaContent);
      expect(metaData['title'], 'Test Title');
      expect(metaData['thumbnailUrl'], 'https://example.com/thumb.jpg');
      expect(metaData['channelId'], 'test_channel');
      expect(MockStreamClient.getManifestCallCount, 1);
    });

    test('clearAllCache handles exceptions gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (MethodCall methodCall) async {
        throw PlatformException(code: 'TEST_ERROR', message: 'Simulated error');
      });

      final cacheService = VideoCacheService();
      await cacheService.clearAllCache();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    });

    test('Confirm that invalidating the cached ID set works', () async {
      var ids = await service.getCachedVideoIds();
      expect(ids, isEmpty);

      final dir = Directory('${tempDir.path}/video_cache');
      await dir.create(recursive: true);
      final videoFile = File('${dir.path}/test_video_1.mp4');
      await videoFile.writeAsString('dummy mp4 content');

      ids = await service.getCachedVideoIds();
      expect(ids, isEmpty);

      service.invalidateCachedIdSetForTest();
      ids = await service.getCachedVideoIds();
      expect(ids, isNotEmpty);
      expect(ids.contains('test_video_1'), isTrue);
    });

    test('cacheVideo exits early if video is already cached', () async {
      final videoId = 'test_video_123';
      final sanitizedId = service.sanitizeVideoId(videoId);
      final cacheDirPath = '${tempDir.path}/video_cache';
      await Directory(cacheDirPath).create(recursive: true);
      final dummyFile = File('$cacheDirPath/$sanitizedId.mp4');
      await dummyFile.writeAsString('original content');

      await service.cacheVideo(videoId);

      expect(await dummyFile.exists(), isTrue);
      expect(await dummyFile.readAsString(), 'original content');
      expect(MockStreamClient.getManifestCallCount, 0);
    });

    test('cacheVideo handles network errors gracefully', () async {
      MockStreamClient.shouldThrow = true;
      final videoId = 'test_video_fail';

      try {
        await service.cacheVideo(videoId);
      } catch (e) {
        // Expected
      }

      final sanitizedId = service.sanitizeVideoId(videoId);
      final videoFile = File('${tempDir.path}/video_cache/$sanitizedId.mp4');
      expect(await videoFile.exists(), isFalse);
    });

    test('cacheVideo respects background pause state', () async {
      final videoId = 'test_video_pause';
      service.pauseBackgroundOperations();

      bool didProceed = false;
      final cacheFuture = service.cacheVideo(videoId).then((_) {
        didProceed = true;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      expect(didProceed, isFalse);

      service.resumeBackgroundOperations();
      try {
        await cacheFuture;
      } catch (_) {}
      expect(didProceed, isTrue);
    });
  });

  group('getCachedStreamUrl', () {
    test('returns null when cache is empty', () async {
      final url = await service.getCachedStreamUrl('empty_video');
      expect(url, isNull);
    });

    test('returns URL from memory cache if present and not expired', () async {
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
