import 'dart:io';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:dadytube/services/video_cache_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

void main() {
  test('writeMetaSidecarForTest writes correctly', () async {
    final tempDir = Directory.systemTemp.createTempSync('video_cache_test');
    final service = VideoCacheService();

    // Test that the meta file is written
    await service.writeMetaSidecarForTest(
      tempDir.path,
      'test_id',
      title: 'Test Title',
      thumbnailUrl: 'http://test.com/thumb.jpg',
      channelId: 'test_channel',
    );

    final metaFile = File('${tempDir.path}/test_id.meta');
    expect(await metaFile.exists(), isTrue);

    final jsonContent = json.decode(await metaFile.readAsString());
    expect(jsonContent['title'], 'Test Title');
    expect(jsonContent['thumbnailUrl'], 'http://test.com/thumb.jpg');
    expect(jsonContent['channelId'], 'test_channel');
    expect(jsonContent.containsKey('cachedAt'), isTrue);

    tempDir.deleteSync(recursive: true);
  });
}
