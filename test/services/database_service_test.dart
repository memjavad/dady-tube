import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:dadytube/services/database_service.dart';
import 'package:dadytube/providers/channel_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService errors', () {
    test('database getter throws when initialization fails', () async {
      // Attempt to force an initialization failure
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'dadytube.db');

      // Ensure no file exists yet
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }

      // Create a directory where the DB file should be, causing openDatabase to fail
      final dir = Directory(path);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      try {
        await expectLater(
          () => DatabaseService.instance.database,
          throwsA(isA<DatabaseException>())
        );
      } finally {
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      }
    });
  });

  group('insertChannel', () {
    setUp(() async {
      // Initialize db if not already, then clear tables
      try {
        final db = await DatabaseService.instance.database;
        await db.delete('videos');
        await db.delete('channels');
      } catch (_) {}
    });

    test('inserts a new channel successfully', () async {
      final channel = YoutubeChannel(
        id: 'channel1',
        name: 'Test Channel',
        thumbnailUrl: 'http://example.com/thumb.jpg',
        localThumbnailPath: '/local/path/thumb.jpg',
      );

      await DatabaseService.instance.insertChannel(channel, lastSync: 12345);

      final channels = await DatabaseService.instance.getChannels();
      expect(channels.length, 1);
      expect(channels.first.id, 'channel1');
      expect(channels.first.name, 'Test Channel');
      expect(channels.first.thumbnailUrl, 'http://example.com/thumb.jpg');
      expect(channels.first.localThumbnailPath, '/local/path/thumb.jpg');

      final db = await DatabaseService.instance.database;
      final results = await db.query('channels', where: 'id = ?', whereArgs: ['channel1']);
      expect(results.first['lastSync'], 12345);
    });

    test('replaces an existing channel on conflict', () async {
      final channel1 = YoutubeChannel(
        id: 'channel1',
        name: 'Test Channel',
        thumbnailUrl: 'http://example.com/thumb.jpg',
      );

      await DatabaseService.instance.insertChannel(channel1, lastSync: 111);

      // Insert another channel with the same ID but different data
      final channel2 = YoutubeChannel(
        id: 'channel1',
        name: 'Updated Channel',
        thumbnailUrl: 'http://example.com/new_thumb.jpg',
        localThumbnailPath: '/new/path.jpg',
      );

      await DatabaseService.instance.insertChannel(channel2, lastSync: 222);

      final channels = await DatabaseService.instance.getChannels();
      expect(channels.length, 1);
      expect(channels.first.name, 'Updated Channel');
      expect(channels.first.thumbnailUrl, 'http://example.com/new_thumb.jpg');
      expect(channels.first.localThumbnailPath, '/new/path.jpg');

      final db = await DatabaseService.instance.database;
      final results = await db.query('channels', where: 'id = ?', whereArgs: ['channel1']);
      expect(results.first['lastSync'], 222);
    });
  });
}
