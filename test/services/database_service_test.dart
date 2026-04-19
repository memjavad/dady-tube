import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dadytube/services/database_service.dart';
import 'package:dadytube/providers/channel_provider.dart';
import 'package:dadytube/services/youtube_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService.instance;
      // Clear database to ensure clean state
      final db = await dbService.database;
      await db.delete('videos');
      await db.delete('channels');
    });

    tearDown(() async {
      final db = await dbService.database;
      await db.delete('videos');
      await db.delete('channels');
    });

    test('insertChannel, getChannels, deleteChannel', () async {
      final channel = YoutubeChannel(
        id: 'channel_1',
        name: 'Test Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        localThumbnailPath: '/local/path/thumb.jpg',
      );

      await dbService.insertChannel(channel, lastSync: 123456);

      var channels = await dbService.getChannels();
      expect(channels.length, 1);
      expect(channels[0].id, 'channel_1');
      expect(channels[0].name, 'Test Channel');

      // delete
      await dbService.deleteChannel('channel_1');
      channels = await dbService.getChannels();
      expect(channels.length, 0);
    });

    test('insertVideos, getVideosForChannel, clearAllVideos', () async {
      final channel = YoutubeChannel(
        id: 'channel_1',
        name: 'Test Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
      await dbService.insertChannel(channel);

      final video1 = YoutubeVideo(
        id: 'video_1',
        title: 'Test Video 1',
        thumbnailUrl: 'https://example.com/vthumb1.jpg',
        channelId: 'channel_1',
        publishedAt: DateTime.parse('2023-01-01T10:00:00Z'),
      );
      final video2 = YoutubeVideo(
        id: 'video_2',
        title: 'Test Video 2',
        thumbnailUrl: 'https://example.com/vthumb2.jpg',
        channelId: 'channel_1',
        publishedAt: DateTime.parse('2023-01-02T10:00:00Z'),
      );

      await dbService.insertVideos([video1, video2]);

      final videos = await dbService.getVideosForChannel('channel_1');
      expect(videos.length, 2);
      // Ordered by publishedAt DESC, so video 2 should be first
      expect(videos[0].id, 'video_2');
      expect(videos[0].title, 'Test Video 2');
      expect(videos[1].id, 'video_1');
      expect(videos[1].title, 'Test Video 1');

      await dbService.clearAllVideos();
      final videosAfterClear = await dbService.getVideosForChannel('channel_1');
      expect(videosAfterClear.length, 0);
    });

    test('insertOrUpdateVideos', () async {
      final channel = YoutubeChannel(
        id: 'channel_1',
        name: 'Test Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
      await dbService.insertChannel(channel);

      final video1 = YoutubeVideo(
        id: 'video_1',
        title: 'Test Video 1',
        thumbnailUrl: 'https://example.com/vthumb1.jpg',
        channelId: 'channel_1',
        publishedAt: DateTime.parse('2023-01-01T10:00:00Z'),
      );

      await dbService.insertVideos([video1]);
      var videos = await dbService.getVideosForChannel('channel_1');
      expect(videos.length, 1);
      expect(videos[0].title, 'Test Video 1');

      // Update the title
      final updatedVideo1 = YoutubeVideo(
        id: 'video_1',
        title: 'Updated Test Video 1',
        thumbnailUrl: 'https://example.com/vthumb1.jpg',
        channelId: 'channel_1',
        publishedAt: DateTime.parse('2023-01-01T10:00:00Z'),
      );

      await dbService.insertOrUpdateVideos([updatedVideo1]);
      videos = await dbService.getVideosForChannel('channel_1');
      expect(videos.length, 1);
      expect(videos[0].title, 'Updated Test Video 1');
    });

    test('getAllVideosMap', () async {
      final channel1 = YoutubeChannel(
        id: 'channel_1',
        name: 'Test Channel 1',
        thumbnailUrl: 'https://example.com/thumb1.jpg',
      );
      final channel2 = YoutubeChannel(
        id: 'channel_2',
        name: 'Test Channel 2',
        thumbnailUrl: 'https://example.com/thumb2.jpg',
      );
      await dbService.insertChannel(channel1);
      await dbService.insertChannel(channel2);

      final video1 = YoutubeVideo(
        id: 'video_1',
        title: 'Test Video 1',
        thumbnailUrl: 'https://example.com/vthumb1.jpg',
        channelId: 'channel_1',
        publishedAt: DateTime.parse('2023-01-01T10:00:00Z'),
      );
      final video2 = YoutubeVideo(
        id: 'video_2',
        title: 'Test Video 2',
        thumbnailUrl: 'https://example.com/vthumb2.jpg',
        channelId: 'channel_2',
        publishedAt: DateTime.parse('2023-01-02T10:00:00Z'),
      );

      await dbService.insertVideos([video1, video2]);

      final videosMap = await dbService.getAllVideosMap(['channel_1', 'channel_2']);
      expect(videosMap.length, 2);
      expect(videosMap['channel_1']!.length, 1);
      expect(videosMap['channel_1']![0].id, 'video_1');
      expect(videosMap['channel_2']!.length, 1);
      expect(videosMap['channel_2']![0].id, 'video_2');
    });

    test('getTotalChannelCount and getTotalVideoCount', () async {
      final channel = YoutubeChannel(
        id: 'channel_1',
        name: 'Test Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
      await dbService.insertChannel(channel);

      final video1 = YoutubeVideo(
        id: 'video_1',
        title: 'Test Video 1',
        thumbnailUrl: 'https://example.com/vthumb1.jpg',
        channelId: 'channel_1',
        publishedAt: DateTime.parse('2023-01-01T10:00:00Z'),
      );

      await dbService.insertVideos([video1]);

      final channelCount = await dbService.getTotalChannelCount();
      expect(channelCount, 1);

      final videoCount = await dbService.getTotalVideoCount();
      expect(videoCount, 1);
    });
  });
}
