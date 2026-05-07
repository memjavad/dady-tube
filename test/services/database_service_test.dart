import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dadytube/services/database_service.dart';
import 'package:dadytube/services/youtube_service.dart';
import 'package:dadytube/providers/channel_provider.dart';

void main() {
  late DatabaseService dbService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbService = DatabaseService.instance;
    await dbService.database; // Ensure DB is initialized
  });

  tearDown(() async {
    final db = await dbService.database;
    await db.delete('videos');
    await db.delete('channels');
  });

  group('DatabaseService Tests', () {
    test('insertChannel and getChannels', () async {
      final channel = YoutubeChannel(
        id: 'c1',
        name: 'Channel 1',
        thumbnailUrl: 'thumb1.jpg',
        localThumbnailPath: 'local1.jpg',
      );

      await dbService.insertChannel(channel, lastSync: 100);

      final channels = await dbService.getChannels();
      expect(channels.length, 1);
      expect(channels.first.id, 'c1');
      expect(channels.first.name, 'Channel 1');
      expect(channels.first.thumbnailUrl, 'thumb1.jpg');
      expect(channels.first.localThumbnailPath, 'local1.jpg');

      // Check lastSync by querying directly since getChannels doesn't return it
      final db = await dbService.database;
      final results = await db.query('channels', where: 'id = ?', whereArgs: ['c1']);
      expect(results.first['lastSync'], 100);
    });

    test('insertChannel updates existing channel', () async {
      final channel = YoutubeChannel(
        id: 'c1',
        name: 'Channel 1',
        thumbnailUrl: 'thumb1.jpg',
      );

      await dbService.insertChannel(channel);

      final updatedChannel = YoutubeChannel(
        id: 'c1', // Same ID
        name: 'Channel 1 Updated',
        thumbnailUrl: 'thumb1_new.jpg',
      );

      await dbService.insertChannel(updatedChannel, lastSync: 200);

      final channels = await dbService.getChannels();
      expect(channels.length, 1);
      expect(channels.first.name, 'Channel 1 Updated');
      expect(channels.first.thumbnailUrl, 'thumb1_new.jpg');

      final db = await dbService.database;
      final results = await db.query('channels', where: 'id = ?', whereArgs: ['c1']);
      expect(results.first['lastSync'], 200);
    });

    test('getTotalChannelCount and getTotalVideoCount', () async {
      expect(await dbService.getTotalChannelCount(), 0);
      expect(await dbService.getTotalVideoCount(), 0);

      await dbService.insertChannel(YoutubeChannel(id: 'c1', name: 'C1', thumbnailUrl: 't1'));
      await dbService.insertChannel(YoutubeChannel(id: 'c2', name: 'C2', thumbnailUrl: 't2'));

      expect(await dbService.getTotalChannelCount(), 2);

      final videos = [
        YoutubeVideo(id: 'v1', title: 'V1', thumbnailUrl: 't1', channelId: 'c1', publishedAt: DateTime.now()),
        YoutubeVideo(id: 'v2', title: 'V2', thumbnailUrl: 't2', channelId: 'c1', publishedAt: DateTime.now()),
        YoutubeVideo(id: 'v3', title: 'V3', thumbnailUrl: 't3', channelId: 'c2', publishedAt: DateTime.now()),
      ];

      await dbService.insertVideos(videos);

      expect(await dbService.getTotalVideoCount(), 3);
    });

    test('insertVideos and getVideosForChannel (orders by publishedAt DESC)', () async {
      await dbService.insertChannel(YoutubeChannel(id: 'c1', name: 'C1', thumbnailUrl: 't1'));

      final now = DateTime.now();
      final videos = [
        YoutubeVideo(id: 'v1', title: 'Old', thumbnailUrl: 't1', channelId: 'c1', publishedAt: now.subtract(const Duration(days: 2))),
        YoutubeVideo(id: 'v2', title: 'New', thumbnailUrl: 't2', channelId: 'c1', publishedAt: now),
        YoutubeVideo(id: 'v3', title: 'Middle', thumbnailUrl: 't3', channelId: 'c1', publishedAt: now.subtract(const Duration(days: 1))),
      ];

      await dbService.insertVideos(videos);

      final channelVideos = await dbService.getVideosForChannel('c1');
      expect(channelVideos.length, 3);
      // Verify descending order
      expect(channelVideos[0].title, 'New');
      expect(channelVideos[1].title, 'Middle');
      expect(channelVideos[2].title, 'Old');
    });

    test('deleteChannel cascades and deletes related videos', () async {
      await dbService.insertChannel(YoutubeChannel(id: 'c1', name: 'C1', thumbnailUrl: 't1'));
      await dbService.insertChannel(YoutubeChannel(id: 'c2', name: 'C2', thumbnailUrl: 't2'));

      await dbService.insertVideos([
        YoutubeVideo(id: 'v1', title: 'V1', thumbnailUrl: 't1', channelId: 'c1', publishedAt: DateTime.now()),
        YoutubeVideo(id: 'v2', title: 'V2', thumbnailUrl: 't2', channelId: 'c2', publishedAt: DateTime.now()),
      ]);

      expect(await dbService.getTotalChannelCount(), 2);
      expect(await dbService.getTotalVideoCount(), 2);

      await dbService.deleteChannel('c1');

      expect(await dbService.getTotalChannelCount(), 1);
      expect(await dbService.getTotalVideoCount(), 1); // v1 should be deleted

      final remainingVideos = await dbService.getVideosForChannel('c2');
      expect(remainingVideos.first.id, 'v2');
    });

    test('clearAllVideos removes all videos but keeps channels', () async {
      await dbService.insertChannel(YoutubeChannel(id: 'c1', name: 'C1', thumbnailUrl: 't1'));
      await dbService.insertVideos([
        YoutubeVideo(id: 'v1', title: 'V1', thumbnailUrl: 't1', channelId: 'c1', publishedAt: DateTime.now()),
      ]);

      expect(await dbService.getTotalChannelCount(), 1);
      expect(await dbService.getTotalVideoCount(), 1);

      await dbService.clearAllVideos();

      expect(await dbService.getTotalChannelCount(), 1);
      expect(await dbService.getTotalVideoCount(), 0);
    });

    test('insertVideos ignores duplicates (conflict algorithm ignore)', () async {
      await dbService.insertChannel(YoutubeChannel(id: 'c1', name: 'C1', thumbnailUrl: 't1'));

      final video = YoutubeVideo(id: 'v1', title: 'V1', thumbnailUrl: 't1', channelId: 'c1', publishedAt: DateTime.now());
      await dbService.insertVideos([video]);

      // Insert exact same video id, different title
      final updatedVideo = YoutubeVideo(id: 'v1', title: 'V1 Updated', thumbnailUrl: 't1', channelId: 'c1', publishedAt: DateTime.now());
      await dbService.insertVideos([updatedVideo]);

      final videos = await dbService.getVideosForChannel('c1');
      expect(videos.length, 1);
      // Since it's ignore, the title should remain the original
      expect(videos.first.title, 'V1');
    });

    test('insertOrUpdateVideos replaces duplicates (conflict algorithm replace)', () async {
      await dbService.insertChannel(YoutubeChannel(id: 'c1', name: 'C1', thumbnailUrl: 't1'));

      final video = YoutubeVideo(id: 'v1', title: 'V1', thumbnailUrl: 't1', channelId: 'c1', publishedAt: DateTime.now());
      await dbService.insertVideos([video]);

      // Insert exact same video id, different title using insertOrUpdateVideos
      final updatedVideo = YoutubeVideo(id: 'v1', title: 'V1 Updated', thumbnailUrl: 't1', channelId: 'c1', publishedAt: DateTime.now());
      await dbService.insertOrUpdateVideos([updatedVideo]);

      final videos = await dbService.getVideosForChannel('c1');
      expect(videos.length, 1);
      // Since it's replace, the title should be updated
      expect(videos.first.title, 'V1 Updated');
    });

    test('getAllVideosMap returns correct map', () async {
      await dbService.insertChannel(YoutubeChannel(id: 'c1', name: 'C1', thumbnailUrl: 't1'));
      await dbService.insertChannel(YoutubeChannel(id: 'c2', name: 'C2', thumbnailUrl: 't2'));

      await dbService.insertVideos([
        YoutubeVideo(id: 'v1', title: 'V1', thumbnailUrl: 't1', channelId: 'c1', publishedAt: DateTime.now()),
        YoutubeVideo(id: 'v2', title: 'V2', thumbnailUrl: 't2', channelId: 'c2', publishedAt: DateTime.now()),
        YoutubeVideo(id: 'v3', title: 'V3', thumbnailUrl: 't3', channelId: 'c2', publishedAt: DateTime.now()),
      ]);

      final map = await dbService.getAllVideosMap(['c1', 'c2']);
      expect(map.keys.length, 2);
      expect(map['c1']!.length, 1);
      expect(map['c2']!.length, 2);
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
}
