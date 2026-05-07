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
import 'package:mocktail/mocktail.dart';
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

class MockYoutubeExplode extends Mock implements yt.YoutubeExplode {}
class MockVideoClient extends Mock implements yt.VideoClient {}
class MockStreamClient extends Mock implements yt.StreamClient {}
class MockStreamManifest extends Mock implements yt.StreamManifest {}
class MockMuxedStreamInfo extends Mock implements yt.MuxedStreamInfo {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late VideoCacheService service;
  late MockYoutubeExplode mockYt;
  late MockVideoClient mockVideoClient;
  late MockStreamClient mockStreamClient;
  late MockClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    // For yt.StreamClient.get
    registerFallbackValue(MockMuxedStreamInfo());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('video_cache_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
    
    mockYt = MockYoutubeExplode();
    mockVideoClient = MockVideoClient();
    mockStreamClient = MockStreamClient();
    
    when(() => mockYt.videos).thenReturn(mockVideoClient);
    when(() => mockVideoClient.streamsClient).thenReturn(mockStreamClient);
    
    mockHttpClient = MockClient((request) async {
      return http.Response('dummy content chunk', 200);
    });

    service = VideoCacheService();
    service.mockYt = mockYt;
    service.mockHttpClient = mockHttpClient;
    
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Video Download and Storage Tests', () {
    test('cacheVideo uses in-memory manifest and writes metadata sidecar', () async {
      final mockManifest = MockStreamManifest();
      final mockStreamInfo = MockMuxedStreamInfo();
      when(() => mockStreamInfo.url).thenReturn(Uri.parse('https://example.com/video.mp4'));
      when(() => mockStreamInfo.size).thenReturn(yt.FileSize(1024));
      when(() => mockStreamInfo.bitrate).thenReturn(yt.Bitrate(1000));
      when(() => mockManifest.muxed).thenReturn(UnmodifiableListView([mockStreamInfo]));
      
      when(() => mockStreamClient.getManifest(any(), fullManifest: any(named: 'fullManifest'), ytClients: any(named: 'ytClients'), requireWatchPage: any(named: 'requireWatchPage')))
          .thenAnswer((_) async => mockManifest);

      // Prepopulate
      await service.getManifest('test_video');
      
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
      
      // Verify only one manifest fetch
      verify(() => mockStreamClient.getManifest('test_video', fullManifest: any(named: 'fullManifest'), ytClients: any(named: 'ytClients'), requireWatchPage: any(named: 'requireWatchPage'))).called(1);
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

      expect(await dummyFile.readAsString(), 'original content');
      verifyNever(() => mockStreamClient.getManifest(any()));
    });

    test('cachePreview accurately fetches from cache', () async {
      final videoId = 'test_video_id';
      final mockManifest = MockStreamManifest();
      final mockStreamInfo = MockMuxedStreamInfo();

      when(() => mockStreamInfo.url).thenReturn(Uri.parse('https://example.com/stream'));
      when(() => mockStreamInfo.size).thenReturn(yt.FileSize(1000));
      when(() => mockStreamInfo.bitrate).thenReturn(yt.Bitrate(1000));
      when(() => mockManifest.muxed).thenReturn(UnmodifiableListView([mockStreamInfo]));

      when(() => mockStreamClient.getManifest(videoId, fullManifest: any(named: 'fullManifest'), ytClients: any(named: 'ytClients'), requireWatchPage: any(named: 'requireWatchPage')))
          .thenAnswer((_) async => mockManifest);
      
      when(() => mockStreamClient.get(any())).thenAnswer(
        (_) => Stream.fromIterable([
          [1, 2, 3],
        ]),
      );

      // Cache it
      await service.getManifest(videoId);
      verify(() => mockStreamClient.getManifest(videoId, fullManifest: any(named: 'fullManifest'), ytClients: any(named: 'ytClients'), requireWatchPage: any(named: 'requireWatchPage'))).called(1);

      // Now call cachePreview
      await service.cachePreview(videoId);

      // Should not call getManifest again
      verifyNever(() => mockStreamClient.getManifest(videoId, fullManifest: any(named: 'fullManifest'), ytClients: any(named: 'ytClients'), requireWatchPage: any(named: 'requireWatchPage')));
      // Should call get to fetch preview
      verify(() => mockStreamClient.get(mockStreamInfo)).called(1);
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

      final url1 = await service.getCachedStreamUrl('mem_video');
      expect(url1, equals(mockUrl));

      await prefs.clear();
      final url2 = await service.getCachedStreamUrl('mem_video');
      expect(url2, equals(mockUrl));
    });
  });
}
