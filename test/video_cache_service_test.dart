import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/services/video_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late VideoCacheService cacheService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('video_cache_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
    SharedPreferences.setMockInitialValues({});
    cacheService = VideoCacheService();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('Confirm that invalidating the cached ID set works when a new video is successfully downloaded', () async {
    // 1. Initial check - should be empty
    var ids = await cacheService.getCachedVideoIds();
    expect(ids, isEmpty, reason: 'Cache should be initially empty');

    // 2. Simulate video download by writing a file behind the scenes
    final cacheDir = Directory('${tempDir.path}/video_cache');
    await cacheDir.create(recursive: true);

    // Use an ID that _sanitizeId won't change
    final testVideoId = 'test_video_1';
    final videoFile = File('${cacheDir.path}/$testVideoId.mp4');
    await videoFile.writeAsString('dummy mp4 content');

    // 3. Since we haven't invalidated the in-memory cache yet, it should still report empty
    ids = await cacheService.getCachedVideoIds();
    expect(ids, isEmpty, reason: 'In-memory cache should not have picked up the new file yet');

    // 4. Invalidate the cache (this is what cacheVideo does after a successful download via _invalidateCachedIdSet())
    cacheService.invalidateCachedIdSetForTest();

    // 5. The next call should rescan the directory and find the new file
    ids = await cacheService.getCachedVideoIds();
    expect(ids, isNotEmpty, reason: 'After invalidation, cache should pick up the new file');
    expect(ids.contains(testVideoId), isTrue, reason: 'Cache should contain the newly downloaded video ID');
  });
}
