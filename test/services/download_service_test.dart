import 'dart:collection';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dadytube/services/download_service.dart';
import 'package:dadytube/services/video_cache_service.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:mocktail/mocktail.dart';

class MockStreamManifest extends Mock implements yt.StreamManifest {}

class MockMuxedStreamInfo extends Mock implements yt.MuxedStreamInfo {}

class MockVideoCacheService extends Mock implements VideoCacheService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DownloadService service;
  late MockVideoCacheService mockVideoCache;
  late MockClient mockHttpClient;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return './test_tmp';
        }
        return null;
      },
    );
    mockVideoCache = MockVideoCacheService();

    final mockManifest = MockStreamManifest();
    final mockMuxedStreamInfo = MockMuxedStreamInfo();

    when(() => mockMuxedStreamInfo.url).thenReturn(Uri.parse('https://example.com/video.mp4'));
    when(() => mockMuxedStreamInfo.size).thenReturn(yt.FileSize(1024));
    when(() => mockManifest.muxed).thenReturn(
      UnmodifiableListView<yt.MuxedStreamInfo>([mockMuxedStreamInfo]),
    );

    mockHttpClient = MockClient((request) async {
      return http.Response('dummy content chunk', 200);
    });

    when(() => mockVideoCache.getManifest('test_video')).thenAnswer((_) async => mockManifest);

    service = DownloadService(
      httpClient: mockHttpClient,
      videoCacheService: mockVideoCache,
    );
  });

  tearDown(() async {
    service.dispose();
    final dir = Directory('./test_tmp');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('DownloadService Tests', () {
    test('sanitizeVideoId removes special characters', () {
      expect(service.sanitizeVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(service.sanitizeVideoId('video?id=123&foo=bar'), 'videoid123foobar');
      expect(service.sanitizeVideoId('../../../etc/passwd'), 'etcpasswd');
    });

    test('getLocalPath returns null when file does not exist', () async {
      SharedPreferences.setMockInitialValues({});
      await Future.delayed(Duration.zero);
      expect(await service.getLocalPath('non_existent_video'), null);
    });

    test('getLocalPath returns path when file exists', () async {
      SharedPreferences.setMockInitialValues({});
      await Future.delayed(Duration.zero);

      final dir = Directory('./test_tmp');
      if (!await dir.exists()) await dir.create();

      final file = File('./test_tmp/existing_video.mp4');
      await file.writeAsString('dummy content');

      final path = await service.getLocalPath('existing_video');
      expect(path, file.path);
    });

    test('isDownloaded returns false when file does not exist', () async {
      SharedPreferences.setMockInitialValues({});
      await Future.delayed(Duration.zero);
      expect(await service.isDownloaded('non_existent_video'), false);
    });

    test('isDownloaded returns true when file exists', () async {
      SharedPreferences.setMockInitialValues({});
      await Future.delayed(Duration.zero);

      final dir = Directory('./test_tmp');
      if (!await dir.exists()) await dir.create();

      final file = File('./test_tmp/existing_video.mp4');
      await file.writeAsString('dummy content');

      expect(await service.isDownloaded('existing_video'), true);
    });

    test('deleteVideo removes file and updates SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'downloaded_video_ids': ['video_to_delete', 'other_video']
      });
      await Future.delayed(Duration.zero);

      final dir = Directory('./test_tmp');
      if (!await dir.exists()) await dir.create();

      final file = File('./test_tmp/video_to_delete.mp4');
      await file.writeAsString('dummy content');

      expect(await file.exists(), true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('downloaded_video_ids')?.contains('video_to_delete'), true);

      await service.deleteVideo('video_to_delete');

      expect(await file.exists(), false);
      expect(prefs.getStringList('downloaded_video_ids')?.contains('video_to_delete'), false);
      expect(prefs.getStringList('downloaded_video_ids')?.contains('other_video'), true);
    });

    test('downloadVideo uses mocked youtube explosion and http client', () async {
      SharedPreferences.setMockInitialValues({});
      await Future.delayed(Duration.zero);

      final dir = Directory('./test_tmp');
      if (!await dir.exists()) await dir.create();
      await service.downloadVideo('test_video', (_) {});

      final isDownloaded = await service.isDownloaded('test_video');
      expect(isDownloaded, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('downloaded_video_ids')?.contains('test_video'), true);

      final file = File('./test_tmp/test_video.mp4');
      expect(await file.exists(), true);
    });
  });
}
