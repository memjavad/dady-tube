import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dadytube/providers/download_provider.dart';
import 'package:dadytube/services/youtube_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String keyMetadata = 'downloaded_metadata';

  late DownloadProvider provider;

  final testVideo1 = YoutubeVideo(
    id: 'test_video_1',
    title: 'Test Video 1',
    thumbnailUrl: 'https://test.com/thumb1.jpg',
    channelId: 'test_channel_1',
    publishedAt: DateTime(2023, 1, 1),
    isLive: false,
  );

  final testVideo2 = YoutubeVideo(
    id: 'test_video_2',
    title: 'Test Video 2',
    thumbnailUrl: 'https://test.com/thumb2.jpg',
    channelId: 'test_channel_1',
    publishedAt: DateTime(2023, 1, 2),
    isLive: false,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DownloadProvider', () {
    test(
      'initializes with empty list when SharedPreferences is empty',
      () async {
        provider = DownloadProvider();
        // Wait for _loadMetadata to finish
        await Future.delayed(Duration.zero);

        expect(provider.downloadedVideos, isEmpty);
      },
    );

    test('loads metadata from SharedPreferences on initialization', () async {
      final initialData = {testVideo1.id: testVideo1.toJson()};
      SharedPreferences.setMockInitialValues({
        keyMetadata: json.encode(initialData),
      });

      provider = DownloadProvider();
      await Future.delayed(Duration.zero);

      expect(provider.downloadedVideos.length, 1);
      expect(provider.downloadedVideos.first.id, testVideo1.id);
      expect(provider.downloadedVideos.first.title, testVideo1.title);
    });

    test(
      'addDownloadedVideo adds video and updates SharedPreferences',
      () async {
        provider = DownloadProvider();
        await Future.delayed(Duration.zero);

        bool listenerCalled = false;
        provider.addListener(() {
          listenerCalled = true;
        });

        await provider.addDownloadedVideo(testVideo1);

        expect(provider.downloadedVideos.length, 1);
        expect(provider.downloadedVideos.first.id, testVideo1.id);
        expect(listenerCalled, isTrue);

        final prefs = await SharedPreferences.getInstance();
        final storedData = prefs.getString(keyMetadata);
        expect(storedData, isNotNull);

        final Map<String, dynamic> decoded = json.decode(storedData!);
        expect(decoded.containsKey(testVideo1.id), isTrue);
        expect(decoded[testVideo1.id]['title'], testVideo1.title);
      },
    );

    test(
      'removeDownloadedVideo removes video and updates SharedPreferences',
      () async {
        final initialData = {
          testVideo1.id: testVideo1.toJson(),
          testVideo2.id: testVideo2.toJson(),
        };
        SharedPreferences.setMockInitialValues({
          keyMetadata: json.encode(initialData),
        });

        provider = DownloadProvider();
        await Future.delayed(Duration.zero);

        expect(provider.downloadedVideos.length, 2);

        bool listenerCalled = false;
        provider.addListener(() {
          listenerCalled = true;
        });

        await provider.removeDownloadedVideo(testVideo1.id);

        expect(provider.downloadedVideos.length, 1);
        expect(provider.downloadedVideos.first.id, testVideo2.id);
        expect(listenerCalled, isTrue);

        final prefs = await SharedPreferences.getInstance();
        final storedData = prefs.getString(keyMetadata);
        final Map<String, dynamic> decoded = json.decode(storedData!);

        expect(decoded.containsKey(testVideo1.id), isFalse);
        expect(decoded.containsKey(testVideo2.id), isTrue);
      },
    );

    test(
      'clearAllDownloads removes all videos and updates SharedPreferences',
      () async {
        final initialData = {
          testVideo1.id: testVideo1.toJson(),
          testVideo2.id: testVideo2.toJson(),
        };
        SharedPreferences.setMockInitialValues({
          keyMetadata: json.encode(initialData),
        });

        provider = DownloadProvider();
        await Future.delayed(Duration.zero);

        expect(provider.downloadedVideos.length, 2);

        bool listenerCalled = false;
        provider.addListener(() {
          listenerCalled = true;
        });

        await provider.clearAllDownloads();

        expect(provider.downloadedVideos, isEmpty);
        expect(listenerCalled, isTrue);

        final prefs = await SharedPreferences.getInstance();
        final storedData = prefs.getString(keyMetadata);
        final Map<String, dynamic> decoded = json.decode(storedData!);

        expect(decoded, isEmpty);
      },
    );
  });
}
