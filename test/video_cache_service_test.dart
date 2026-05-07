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

// Since the mockito code generator is not run, we just do exactly what download_service_test.dart did which compiled fine!
// It manually extended Mock and implemented yt interfaces.
// We will also stub `bitrate` to prevent runtime crashes.

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

  @override
  Future<yt.StreamManifest> getManifest(dynamic videoId, {bool fullManifest = false, List<yt.YoutubeApiClient>? ytClients, bool requireWatchPage = false}) async {
    getManifestCallCount++;
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

  late VideoCacheService service;
  late MockYoutubeExplode mockYtClient;
  late MockClient mockHttpClient;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return './test_tmp';
        }
        return null;
      },
    );
    mockYtClient = MockYoutubeExplode();

    mockHttpClient = MockClient((request) async {
      return http.Response('dummy content chunk', 200);
    });

    service = VideoCacheService();
    service.mockYt = mockYtClient;
    service.mockHttpClient = mockHttpClient;
    MockStreamClient.getManifestCallCount = 0;
  });

  tearDown(() async {
    final dir = Directory('./test_tmp/video_cache');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await service.clearAllCache();
  });

  test('cacheVideo uses in-memory manifest and writes metadata sidecar', () async {
    SharedPreferences.setMockInitialValues({});
    await Future.delayed(Duration.zero);

    // First call getManifest directly to prepopulate the in-memory manifest cache
    await service.getManifest('test_video');
    expect(MockStreamClient.getManifestCallCount, 1);

    // Make sure our test file gets deleted if left over
    final dir = Directory('./test_tmp/video_cache');
    if (!await dir.exists()) await dir.create(recursive: true);

    await service.cacheVideo(
      'test_video',
      title: 'Test Title',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      channelId: 'test_channel',
    );

    // Verify sidecar was written
    final metaFile = File('./test_tmp/video_cache/test_video.meta');
    expect(await metaFile.exists(), isTrue);

    // Verify sidecar content
    final metaContent = await metaFile.readAsString();
    final metaData = json.decode(metaContent);
    expect(metaData['title'], 'Test Title');
    expect(metaData['thumbnailUrl'], 'https://example.com/thumb.jpg');
    expect(metaData['channelId'], 'test_channel');
    expect(metaData.containsKey('cachedAt'), isTrue);

    // Verify manifest reuse (no additional call to getManifest)
    expect(MockStreamClient.getManifestCallCount, 1);
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
