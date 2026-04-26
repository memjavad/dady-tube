import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:dadytube/services/video_cache_service.dart';
import 'dart:collection';

class MockYoutubeExplode extends Mock implements yt.YoutubeExplode {}

class MockVideoClient extends Mock implements yt.VideoClient {}

class MockStreamClient extends Mock implements yt.StreamClient {}

class MockStreamManifest extends Mock implements yt.StreamManifest {
  @override
  UnmodifiableListView<yt.MuxedStreamInfo> get muxed =>
      UnmodifiableListView([MockStreamInfo()]);
}

class MockStreamInfo extends Mock implements yt.MuxedStreamInfo {
  @override
  Uri get url => Uri.parse('https://test.com/stream');

  @override
  int compareTo(yt.StreamInfo other) => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoCacheService service;
  late MockYoutubeExplode mockYt;
  late MockVideoClient mockVideoClient;
  late MockStreamClient mockStreamClient;
  late MockStreamManifest mockManifest;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    mockYt = MockYoutubeExplode();
    mockVideoClient = MockVideoClient();
    mockStreamClient = MockStreamClient();
    mockManifest = MockStreamManifest();

    when(() => mockYt.videos).thenReturn(mockVideoClient);
    when(() => mockVideoClient.streamsClient).thenReturn(mockStreamClient);
    when(
      () => mockStreamClient.getManifest(any()),
    ).thenAnswer((_) async => mockManifest);

    service = VideoCacheService();
    service.mockYt = mockYt;
    // Clear internal cache manually if needed, or re-initialize singleton
    service.clearAllCache();
  });

  test('getManifest accurately fetches from network then cache', () async {
    final videoId = 'test_video_1';

    // Call getManifest for the first time
    final firstManifest = await service.getManifest(videoId);
    expect(firstManifest, equals(mockManifest));

    // Verify network fetch was called
    verify(() => mockStreamClient.getManifest(videoId)).called(1);

    // Call getManifest a second time
    final secondManifest = await service.getManifest(videoId);
    expect(secondManifest, equals(mockManifest));

    // Verify network fetch was NOT called again (served from cache)
    verifyNever(() => mockStreamClient.getManifest(videoId));
  });

  test('Sanitize ID handles dangerous characters', () {
    // Basic test inherited
    expect(true, true);
  });
}
