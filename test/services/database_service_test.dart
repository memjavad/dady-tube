import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dadytube/services/database_service.dart';
import 'package:dadytube/providers/channel_provider.dart';
import 'package:dadytube/services/youtube_service.dart';
import 'package:path/path.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService.instance;
      // Close existing db if any to allow deletion
      // But DatabaseService._database is static, we can't easily reset it
      // unless we clear the tables.
      await dbService.clearAllVideos();
      // Also clear channels
      final db = await dbService.database;
      await db.delete('channels');
    });

    group('getVideosForChannel', () {
      test('returns empty list when no videos exist for channel', () async {
        final videos = await dbService.getVideosForChannel('channel_1');
        expect(videos, isEmpty);
      });

      test('returns correct videos ordered by publishedAt DESC', () async {
        final channel1 = YoutubeChannel(
          id: 'channel_1',
          name: 'Test Channel 1',
          thumbnailUrl: 'thumb1',
        );
        final channel2 = YoutubeChannel(
          id: 'channel_2',
          name: 'Test Channel 2',
          thumbnailUrl: 'thumb2',
        );
        await dbService.insertChannel(channel1);
        await dbService.insertChannel(channel2);

        final video1 = YoutubeVideo(
          id: 'v1',
          title: 'Video 1',
          thumbnailUrl: 'vthumb1',
          channelId: 'channel_1',
          publishedAt: DateTime(2023, 1, 1),
        );
        final video2 = YoutubeVideo(
          id: 'v2',
          title: 'Video 2',
          thumbnailUrl: 'vthumb2',
          channelId: 'channel_1',
          publishedAt: DateTime(2023, 1, 3), // newer
        );
        final video3 = YoutubeVideo(
          id: 'v3',
          title: 'Video 3',
          thumbnailUrl: 'vthumb3',
          channelId: 'channel_2', // different channel
          publishedAt: DateTime(2023, 1, 2),
        );

        await dbService.insertVideos([video1, video2, video3]);

        final videos = await dbService.getVideosForChannel('channel_1');

        expect(videos.length, 2);
        // DESC order
        expect(videos[0].id, 'v2');
        expect(videos[0].title, 'Video 2');
        expect(videos[0].thumbnailUrl, 'vthumb2');
        expect(videos[0].channelId, 'channel_1');
        expect(videos[0].publishedAt, DateTime(2023, 1, 3));

        expect(videos[1].id, 'v1');
      });

      test('handles invalid publishedAt dates gracefully', () async {
        final db = await dbService.database;
        await dbService.insertChannel(YoutubeChannel(
          id: 'channel_1',
          name: 'Test Channel 1',
          thumbnailUrl: 'thumb1',
        ));

        await db.insert(
          'videos',
          {
            'id': 'v_invalid',
            'channelId': 'channel_1',
            'title': 'Video Invalid Date',
            'thumbnailUrl': 'vthumb_invalid',
            'publishedAt': 'invalid-date-string',
          },
        );

        final videos = await dbService.getVideosForChannel('channel_1');
        expect(videos.length, 1);
        expect(videos[0].id, 'v_invalid');
        // Because of ?? DateTime.now(), it should be close to now
        expect(videos[0].publishedAt.difference(DateTime.now()).inSeconds.abs(), lessThan(2));
      });
    });
  });
}
