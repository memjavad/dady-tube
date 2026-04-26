import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dadytube/services/database_service.dart';
import 'package:dadytube/providers/channel_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await DatabaseService.instance.database;
    await db.delete('videos');
    await db.delete('channels');
  });

  test('insertChannel correctly inserts a channel into the database', () async {
    final channel = YoutubeChannel(
      id: 'test_id',
      name: 'Test Channel',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      localThumbnailPath: '/local/path/thumb.jpg',
    );

    await DatabaseService.instance.insertChannel(channel, lastSync: 123456789);

    final channels = await DatabaseService.instance.getChannels();
    expect(channels.length, 1);
    expect(channels.first.id, 'test_id');
    expect(channels.first.name, 'Test Channel');
    expect(channels.first.thumbnailUrl, 'https://example.com/thumb.jpg');
    expect(channels.first.localThumbnailPath, '/local/path/thumb.jpg');

    // Check lastSync by querying directly since getChannels doesn't return it
    final db = await DatabaseService.instance.database;
    final results = await db.query('channels', where: 'id = ?', whereArgs: ['test_id']);
    expect(results.first['lastSync'], 123456789);

    // Test conflict algorithm (replace)
    final updatedChannel = YoutubeChannel(
      id: 'test_id',
      name: 'Updated Channel',
      thumbnailUrl: 'https://example.com/thumb2.jpg',
      localThumbnailPath: '/local/path/thumb2.jpg',
    );
    await DatabaseService.instance.insertChannel(updatedChannel, lastSync: 987654321);

    final updatedChannels = await DatabaseService.instance.getChannels();
    expect(updatedChannels.length, 1);
    expect(updatedChannels.first.name, 'Updated Channel');
    expect(updatedChannels.first.thumbnailUrl, 'https://example.com/thumb2.jpg');
    expect(updatedChannels.first.localThumbnailPath, '/local/path/thumb2.jpg');

    final updatedResults = await db.query('channels', where: 'id = ?', whereArgs: ['test_id']);
    expect(updatedResults.first['lastSync'], 987654321);
  });
}
