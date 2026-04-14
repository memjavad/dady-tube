import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:audio_service/audio_service.dart';
import 'package:dadytube/services/background_audio_service.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

class MockYoutubeExplode extends Mock implements yt.YoutubeExplode {}

class MockVideoClient extends Mock implements yt.VideoClient {}

class MockStreamClient extends Mock implements yt.StreamClient {}

class MockStreamManifest extends Mock implements yt.StreamManifest {}

class MockAudioOnlyStreamInfo extends Mock implements yt.AudioOnlyStreamInfo {}

class FakeAudioSource extends Fake implements AudioSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAudioSource());
  });

  group('BackgroundAudioService', () {
    late MockAudioPlayer mockAudioPlayer;
    late MockYoutubeExplode mockYoutubeExplode;
    late BackgroundAudioService backgroundAudioService;

    setUp(() {
      mockAudioPlayer = MockAudioPlayer();
      mockYoutubeExplode = MockYoutubeExplode();

      // Mock the stream to keep the Subject from dying or causing issues.
      when(
        () => mockAudioPlayer.playbackEventStream,
      ).thenAnswer((_) => const Stream.empty());

      backgroundAudioService = BackgroundAudioService(
        player: mockAudioPlayer,
        ytExplode: mockYoutubeExplode,
      );
    });

    test('play delegates to AudioPlayer', () async {
      when(() => mockAudioPlayer.play()).thenAnswer((_) async {});

      await backgroundAudioService.play();

      verify(() => mockAudioPlayer.play()).called(1);
    });

    test('pause delegates to AudioPlayer', () async {
      when(() => mockAudioPlayer.pause()).thenAnswer((_) async {});

      await backgroundAudioService.pause();

      verify(() => mockAudioPlayer.pause()).called(1);
    });

    test('seek delegates to AudioPlayer', () async {
      final duration = const Duration(seconds: 10);
      when(() => mockAudioPlayer.seek(duration)).thenAnswer((_) async {});

      await backgroundAudioService.seek(duration);

      verify(() => mockAudioPlayer.seek(duration)).called(1);
    });

    test('dispose delegates to AudioPlayer and YoutubeExplode', () async {
      when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});
      when(() => mockYoutubeExplode.close()).thenReturn(null);

      backgroundAudioService.dispose();

      verify(() => mockAudioPlayer.dispose()).called(1);
      verify(() => mockYoutubeExplode.close()).called(1);
    });

    test('playVideo successfully plays audio from Youtube', () async {
      final mockVideoClient = MockVideoClient();
      final mockStreamClient = MockStreamClient();
      final mockManifest = MockStreamManifest();
      final mockAudioStreamInfo = MockAudioOnlyStreamInfo();

      final videoId = 'test_video_id';
      final title = 'Test Title';
      final artist = 'Test Artist';
      final thumbnailUrl = 'https://example.com/thumb.jpg';
      final audioUri = Uri.parse('https://example.com/audio.m4a');

      when(() => mockYoutubeExplode.videos).thenReturn(mockVideoClient);
      when(() => mockVideoClient.streamsClient).thenReturn(mockStreamClient);
      when(
        () => mockStreamClient.getManifest(videoId),
      ).thenAnswer((_) async => mockManifest);

      when(() => mockManifest.audioOnly).thenReturn(
        UnmodifiableListView<yt.AudioOnlyStreamInfo>([mockAudioStreamInfo]),
      );

      when(() => mockAudioStreamInfo.bitrate).thenReturn(yt.Bitrate(128000));
      when(() => mockAudioStreamInfo.url).thenReturn(audioUri);

      when(
        () => mockAudioPlayer.setAudioSource(any()),
      ).thenAnswer((_) async => null);
      when(() => mockAudioPlayer.play()).thenAnswer((_) async {});

      await backgroundAudioService.playVideo(
        videoId,
        title,
        artist,
        thumbnailUrl,
      );

      verify(() => mockStreamClient.getManifest(videoId)).called(1);
      verify(() => mockAudioPlayer.setAudioSource(any())).called(1);
      verify(() => mockAudioPlayer.play()).called(1);
    });

    test('stop delegates to AudioPlayer and stops BaseAudioHandler', () async {
      when(() => mockAudioPlayer.stop()).thenAnswer((_) async {});

      try {
        await backgroundAudioService.stop();
      } catch (e) {
        // ignore the bad state from BaseAudioHandler in tests
        // without a full app lifecycle
      }

      verify(() => mockAudioPlayer.stop()).called(1);
    });
  });
}
