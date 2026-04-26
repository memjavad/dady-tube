import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dadytube/services/database_service.dart';
import 'package:dadytube/services/youtube_service.dart';
import 'package:dadytube/providers/channel_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService', () {
    late DatabaseService databaseService;

    setUp(() async {
      databaseService = DatabaseService.instance;
      // Ensure clean state by clearing channels and videos
      final db = await databaseService.database;
      await db.delete('videos');
      await db.delete('channels');
    });

    tearDown(() async {
      final db = await databaseService.database;
      await db.delete('videos');
      await db.delete('channels');
    });

    test('deleteChannel deletes the channel and related videos (Cascade Delete)', () async {
      // 1. Setup Data
      final channelId = 'test_channel_id_for_deletion';
      final channel = YoutubeChannel(
        id: channelId,
        name: 'Test Channel To Delete',
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
      );

      final video1 = YoutubeVideo(
        id: 'test_video_id_1',
        title: 'Test Video 1',
        thumbnailUrl: 'https://example.com/v1.jpg',
        channelId: channelId,
        publishedAt: DateTime.now(),
      );

      final video2 = YoutubeVideo(
        id: 'test_video_id_2',
        title: 'Test Video 2',
        thumbnailUrl: 'https://example.com/v2.jpg',
        channelId: channelId,
        publishedAt: DateTime.now(),
      );

      // 2. Insert Data
      await databaseService.insertChannel(channel);
      await databaseService.insertVideos([video1, video2]);

      // Verify insertion
      final initialChannels = await databaseService.getChannels();
      expect(initialChannels.length, 1);
      expect(initialChannels.first.id, channelId);

      final initialVideos = await databaseService.getVideosForChannel(channelId);
      expect(initialVideos.length, 2);

      // 3. Execute Deletion
      await databaseService.deleteChannel(channelId);

      // 4. Verify Deletion
      final channelsAfterDeletion = await databaseService.getChannels();
      expect(channelsAfterDeletion, isEmpty);

      final videosAfterDeletion = await databaseService.getVideosForChannel(channelId);
      expect(videosAfterDeletion, isEmpty);
    });

    test('deleteChannel when channel does not exist does not throw', () async {
      // Execute deletion on non-existent ID
      await expectLater(
        databaseService.deleteChannel('non_existent_channel_id'),
        completes,
      );
    });
  });
}
