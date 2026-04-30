import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../providers/channel_provider.dart';
import 'youtube_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dadytube.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Upgraded from 1
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const nullableTextType = 'TEXT';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE channels (
  id $idType,
  name $textType,
  thumbnailUrl $textType,
  localThumbnailPath $nullableTextType,
  lastSync $intType
)
''');

    await db.execute('''
CREATE TABLE videos (
  id $idType,
  channelId $textType,
  title $textType,
  thumbnailUrl $textType,
  publishedAt $textType,
  FOREIGN KEY (channelId) REFERENCES channels (id) ON DELETE CASCADE
)
''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE channels ADD COLUMN localThumbnailPath TEXT');
    }
  }

  // --- Channels ---

  Future<void> insertChannel(YoutubeChannel channel, {int lastSync = 0}) async {
    final db = await instance.database;
    await db.insert(
      'channels',
      {
        'id': channel.id,
        'name': channel.name,
        'thumbnailUrl': channel.thumbnailUrl,
        'localThumbnailPath': channel.localThumbnailPath,
        'lastSync': lastSync,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<YoutubeChannel>> getChannels() async {
    final db = await instance.database;
    final result = await db.query('channels');

    return result.map((json) => YoutubeChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      localThumbnailPath: json['localThumbnailPath'] as String?,
    )).toList();
  }

  Future<void> deleteChannel(String id) async {
    final db = await instance.database;
    await db.delete('channels', where: 'id = ?', whereArgs: [id]);
    await db.delete(
      'videos',
      where: 'channelId = ?',
      whereArgs: [id],
    ); // Also delete related videos
  }

  // --- Videos ---

  Future<void> insertVideos(List<YoutubeVideo> videos) async {
    final db = await instance.database;

    Batch batch = db.batch();
    for (var video in videos) {
      batch.insert(
        'videos',
        {
          'id': video.id,
          'channelId': video.channelId,
          'title': video.title,
          'thumbnailUrl': video.thumbnailUrl,
          'publishedAt': video.publishedAt
              .toIso8601String(), // Store as string for flexibility
        },
        conflictAlgorithm: ConflictAlgorithm
            .ignore, // Ignore means we keep the existing rows (no overwriting necessary if it's identical). Alternatively, replace to update thumbnail.
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertOrUpdateVideos(List<YoutubeVideo> videos) async {
    final db = await instance.database;

    Batch batch = db.batch();
    for (var video in videos) {
      batch.insert(
        'videos',
        {
          'id': video.id,
          'channelId': video.channelId,
          'title': video.title,
          'thumbnailUrl': video.thumbnailUrl,
          'publishedAt': video.publishedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace, // Replace for updates
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<YoutubeVideo>> getVideosForChannel(String channelId) async {
    final db = await instance.database;
    final result = await db.query(
      'videos',
      where: 'channelId = ?',
      whereArgs: [channelId],
      orderBy: 'publishedAt DESC', // YouTube order
    );

    return result
        .map(
          (json) => YoutubeVideo(
            id: json['id'] as String,
            title: json['title'] as String,
            thumbnailUrl: json['thumbnailUrl'] as String,
            channelId: json['channelId'] as String,
            publishedAt:
                DateTime.tryParse(json['publishedAt'] as String) ??
                DateTime.now(),
          ),
        )
        .toList();
  }
  /// ⚡ Bolt: Single batch query — fetch all videos for channels in one go
  Future<Map<String, List<YoutubeVideo>>> getAllVideosMap(List<String> channelIds) async {
    if (channelIds.isEmpty) return {};

    final db = await instance.database;
    final placeholders = List.filled(channelIds.length, '?').join(',');

    final result = await db.query(
      'videos',
      where: 'channelId IN ($placeholders)',
      whereArgs: channelIds,
      orderBy: 'publishedAt DESC',
    );

    final videos = result.map(
      (json) => YoutubeVideo(
        id: json['id'] as String,
        title: json['title'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String,
        channelId: json['channelId'] as String,
        publishedAt: DateTime.tryParse(json['publishedAt'] as String) ?? DateTime.now(),
      ),
    ).toList();

    final Map<String, List<YoutubeVideo>> map = {};
    for (var id in channelIds) {
      map[id] = [];
    }
    for (var video in videos) {
      map[video.channelId]?.add(video);
    }
    return map;
  }

  Future<int> getTotalChannelCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM channels');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalVideoCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM videos');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearAllVideos() async {
    final db = await instance.database;
    await db.delete('videos');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
