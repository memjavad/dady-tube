import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/services/download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:mocktail/mocktail.dart';
import 'dart:collection';
import 'package:http/http.dart' as http;

class MockYoutubeExplode extends Mock implements yt.YoutubeExplode {}

class MockVideoClient extends Mock implements yt.VideoClient {}

class MockStreamClient extends Mock implements yt.StreamClient {}

class MockStreamManifest extends Mock implements yt.StreamManifest {}

class MockMuxedStreamInfo extends Mock implements yt.MuxedStreamInfo {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadService', () {
    late DownloadService downloadService;
    late Directory testDir;
    late MockYoutubeExplode mockYtClient;
    late MockVideoClient mockVideoClient;
    late MockStreamClient mockStreamClient;
    late MockHttpClient mockHttpClient;

    setUpAll(() async {
      testDir = await Directory.systemTemp.createTemp('download_service_test');

      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return testDir.path;
            }
            return null;
          });
      registerFallbackValue(Uri.parse('https://example.com'));
      registerFallbackValue(
        http.Request('GET', Uri.parse('https://example.com')),
      );
    });

    tearDownAll(() async {
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockYtClient = MockYoutubeExplode();
      mockVideoClient = MockVideoClient();
      mockStreamClient = MockStreamClient();
      mockHttpClient = MockHttpClient();

      when(() => mockYtClient.videos).thenReturn(mockVideoClient);
      when(() => mockVideoClient.streamsClient).thenReturn(mockStreamClient);

      downloadService = DownloadService(
        ytClient: mockYtClient,
        httpClientFactory: () => mockHttpClient,
      );
      await Future.delayed(Duration.zero);
    });

    tearDown(() {
      downloadService.dispose();
    });

    test('sanitizeVideoId removes invalid characters', () {
      expect(downloadService.sanitizeVideoId('valid_ID-123'), 'valid_ID-123');
      expect(
        downloadService.sanitizeVideoId('invalid|id*with:chars'),
        'invalididwithchars',
      );
      expect(
        downloadService.sanitizeVideoId('id/with\\slashes'),
        'idwithslashes',
      );
      expect(downloadService.sanitizeVideoId('id?with=query'), 'idwithquery');
    });

    test('isDownloaded returns false for non-existent video', () async {
      final result = await downloadService.isDownloaded('non_existent_id');
      expect(result, isFalse);
    });

    test('getLocalPath returns null for non-existent video', () async {
      final result = await downloadService.getLocalPath('non_existent_id');
      expect(result, isNull);
    });

    test('isDownloaded returns true when file exists', () async {
      final videoId = 'test_video_id';
      final file = File('${testDir.path}/test_video_id.mp4');
      await file.writeAsString('dummy content');

      final result = await downloadService.isDownloaded(videoId);
      expect(result, isTrue);
    });

    test('getLocalPath returns correct path when file exists', () async {
      final videoId = 'test_video_id_2';
      final file = File('${testDir.path}/test_video_id_2.mp4');
      await file.writeAsString('dummy content');

      final result = await downloadService.getLocalPath(videoId);
      expect(result, file.path);
    });

    test('deleteVideo removes file and shared preferences entry', () async {
      final videoId = 'test_video_id_3';
      final file = File('${testDir.path}/test_video_id_3.mp4');
      await file.writeAsString('dummy content');

      SharedPreferences.setMockInitialValues({
        'downloaded_video_ids': [videoId, 'other_id'],
      });

      await downloadService.deleteVideo(videoId);

      expect(await file.exists(), isFalse);

      final prefs = await SharedPreferences.getInstance();
      final downloaded = prefs.getStringList('downloaded_video_ids');
      expect(downloaded, ['other_id']);
    });

    test('downloadVideo throws when stream is missing', () async {
      final videoId = 'test_video_no_stream';
      final mockManifest = MockStreamManifest();

      when(
        () => mockStreamClient.getManifest(videoId),
      ).thenAnswer((_) async => mockManifest);
      // It doesn't find a muxed stream (StateError on withHighestBitrate)
      when(
        () => mockManifest.muxed,
      ).thenReturn(UnmodifiableListView<yt.MuxedStreamInfo>([]));

      // Attempt download and expect StateError
      await expectLater(
        downloadService.downloadVideo(videoId, (progress) {}),
        throwsA(isA<StateError>()),
      );
    });

    test('downloadVideo successfully downloads file', () async {
      final videoId = 'test_video_success';
      final mockManifest = MockStreamManifest();
      final mockStreamInfo = MockMuxedStreamInfo();

      when(
        () => mockStreamClient.getManifest(videoId),
      ).thenAnswer((_) async => mockManifest);
      when(
        () => mockManifest.muxed,
      ).thenReturn(UnmodifiableListView<yt.MuxedStreamInfo>([mockStreamInfo]));
      when(() => mockStreamInfo.bitrate).thenReturn(yt.Bitrate(128));
      when(
        () => mockStreamInfo.url,
      ).thenReturn(Uri.parse('https://example.com/video.mp4'));
      when(() => mockStreamInfo.size).thenReturn(yt.FileSize(100)); // 100 bytes

      // Mock Http Response for each segment download chunk
      when(() => mockHttpClient.send(any())).thenAnswer((_) async {
        return http.StreamedResponse(Stream.value([1]), 200);
      });

      await downloadService.downloadVideo(videoId, (p) {});

      final file = File('${testDir.path}/$videoId.mp4');
      expect(await file.exists(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('downloaded_video_ids'), contains(videoId));
    });
  });
}
