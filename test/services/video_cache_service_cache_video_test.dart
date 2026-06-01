import 'dart:io';
import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dadytube/services/video_cache_service.dart';
import 'package:flutter/services.dart';
import 'video_cache_service_cache_video_test.mocks.dart';

class FakeFileSize extends Fake implements yt.FileSize {
  final int _totalBytes;
  FakeFileSize(this._totalBytes);
  @override
  int get totalBytes => _totalBytes;
}

class _FakeVideoClient extends Fake implements yt.VideoClient {
  final yt.StreamClient mockStreamClient;
  _FakeVideoClient(this.mockStreamClient);
  @override
  yt.StreamClient get streamsClient => mockStreamClient;
}

@GenerateNiceMocks([
  MockSpec<yt.YoutubeExplode>(),
  MockSpec<yt.StreamClient>(),
  MockSpec<yt.StreamManifest>(),
  MockSpec<yt.MuxedStreamInfo>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('video_cache_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory' ||
            methodCall.method == 'getTemporaryDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'cacheVideo successfully caches video using mocked HTTP client',
    () async {
      final mockYt = MockYoutubeExplode();
      final mockStreamClient = MockStreamClient();
      final mockManifest = MockStreamManifest();
      final mockMuxedInfo = MockMuxedStreamInfo();

      final videoId = 'test_video_123';
      final streamUrl = Uri.parse('https://example.com/stream');
      final streamSize = 100; // 100 bytes total

      final fakeVideoClient = _FakeVideoClient(mockStreamClient);
      when(mockYt.videos).thenReturn(fakeVideoClient);

      when(
        mockStreamClient.getManifest(any, ytClients: anyNamed('ytClients')),
      ).thenAnswer((_) async => mockManifest);

      when(mockMuxedInfo.url).thenReturn(streamUrl);
      when(mockMuxedInfo.size).thenReturn(FakeFileSize(streamSize));

      when(
        mockManifest.muxed,
      ).thenReturn(UnmodifiableListView([mockMuxedInfo]));

      int requestCount = 0;
      final mockHttpClient = MockClient((request) async {
        requestCount++;
        return http.Response.bytes(
          List.filled(50, 0),
          200,
          headers: {'content-length': '50'},
        );
      });

      final service = VideoCacheService()
        ..mockYt = mockYt
        ..mockHttpClient = mockHttpClient;

      await Future.delayed(Duration.zero);

      await service.cacheVideo(videoId);

      expect(requestCount, 2);

      final cacheDir = '${tempDir.path}/video_cache';

      final expectedFile = File('$cacheDir/$videoId.mp4');
      expect(expectedFile.existsSync(), isTrue);
      expect(expectedFile.lengthSync(), 100);
    },
  );

  test('cacheVideo aborts early if existing video is found', () async {
    final videoId = 'test_video_123_existing';
    final cacheDir = '${tempDir.path}/video_cache';
    await Directory(cacheDir).create(recursive: true);
    final expectedFile = File('$cacheDir/$videoId.mp4');
    await expectedFile.writeAsBytes(List.filled(10, 0));

    final service = VideoCacheService()
      ..mockHttpClient = MockClient((request) async {
        fail('Should not make HTTP requests if file already exists');
      });

    await Future.delayed(Duration.zero);
    await service.cacheVideo(videoId);

    expect(expectedFile.existsSync(), isTrue);
  });

  test(
    'cacheVideo cleans up temporary parts if HTTP request throws exception',
    () async {
      final mockYt = MockYoutubeExplode();
      final mockStreamClient = MockStreamClient();
      final mockManifest = MockStreamManifest();
      final mockMuxedInfo = MockMuxedStreamInfo();

      final videoId = 'test_video_123_error';
      final streamUrl = Uri.parse('https://example.com/stream');
      final streamSize = 100;

      final fakeVideoClient = _FakeVideoClient(mockStreamClient);
      when(mockYt.videos).thenReturn(fakeVideoClient);
      when(
        mockStreamClient.getManifest(any, ytClients: anyNamed('ytClients')),
      ).thenAnswer((_) async => mockManifest);
      when(mockMuxedInfo.url).thenReturn(streamUrl);
      when(mockMuxedInfo.size).thenReturn(FakeFileSize(streamSize));
      when(
        mockManifest.muxed,
      ).thenReturn(UnmodifiableListView([mockMuxedInfo]));

      final mockHttpClient = MockClient((request) async {
        throw const SocketException('Network failed');
      });

      final service = VideoCacheService()
        ..mockYt = mockYt
        ..mockHttpClient = mockHttpClient;

      await Future.delayed(Duration.zero);

      await service.cacheVideo(videoId);

      final cacheDir = '${tempDir.path}/video_cache';
      final expectedFile = File('$cacheDir/$videoId.mp4');
      expect(expectedFile.existsSync(), isFalse);

      // Ensure temporary part files are deleted
      for (int i = 0; i < 2; i++) {
        final partFile = File('$cacheDir/$videoId.mp4.part$i');
        expect(partFile.existsSync(), isFalse);
      }
    },
  );
}
