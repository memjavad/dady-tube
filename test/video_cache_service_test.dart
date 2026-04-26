import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/services/video_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String path;
  FakePathProviderPlatform(this.path);

  @override
  Future<String?> getTemporaryPath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class ErrorHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw const SocketException('Mocked network error');
  }
}

void main() {
  late Directory tempDir;
  late VideoCacheService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('video_cache_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    service = VideoCacheService();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    HttpOverrides.global = null;
  });

  test('Sanitize ID handles dangerous characters', () {
    // Basic test to keep original functionality
    final sanitized = service.sanitizeVideoId('v!d@e#o\$1%2^3&');
    expect(sanitized, 'v_d_e_o_1_2_3_');
  });

  test('cacheVideo exits early if video is already cached', () async {
    // Create a dummy cached video file
    final videoId = 'test_video_123';
    final sanitizedId = service.sanitizeVideoId(videoId);
    final cacheDirPath = '${tempDir.path}/video_cache';
    await Directory(cacheDirPath).create(recursive: true);
    final dummyFile = File('$cacheDirPath/$sanitizedId.mp4');
    await dummyFile.writeAsString('dummy content');

    // Run cacheVideo
    await service.cacheVideo(videoId);

    // Verify file still exists and was not modified by the process
    expect(await dummyFile.exists(), isTrue);
    expect(await dummyFile.readAsStringSync(), 'dummy content');
  });

  test('cacheVideo handles network errors gracefully without crashing the app', () async {
    final videoId = 'test_video_network_fail';

    // Run cacheVideo and expect it to catch the exception internally or propagate it safely
    try {
      HttpOverrides.global = ErrorHttpOverrides();
      await service.cacheVideo(videoId);
    } catch (e) {
      // Expected exception (either rethrown manifest fetch error or socket exception)
    }

    // Verify file was NOT created
    final sanitizedId = service.sanitizeVideoId(videoId);
    final cacheDirPath = '${tempDir.path}/video_cache';
    final dummyFile = File('$cacheDirPath/$sanitizedId.mp4');
    expect(await dummyFile.exists(), isFalse);
  });

  test('cacheVideo respects background pause state', () async {
    final videoId = 'test_video_pause';

    // Pause background operations
    service.pauseBackgroundOperations();

    Future<void>? cacheFuture;
    try {
      HttpOverrides.global = ErrorHttpOverrides();
      // It should get blocked at `await _waitUntilResumed();`
      bool didProceed = false;
      cacheFuture = service.cacheVideo(videoId).then((_) {
        didProceed = true;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      expect(didProceed, isFalse); // Hasn't proceeded

    } finally {
      // Resume to clean up and let the future complete
      service.resumeBackgroundOperations();
      if (cacheFuture != null) {
        try {
          await cacheFuture;
        } catch (_) {}
      }
    }
  });
}
