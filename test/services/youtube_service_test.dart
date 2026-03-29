import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dadytube/services/youtube_service.dart';
import 'package:dadytube/providers/channel_provider.dart';

import 'youtube_service_test.mocks.dart';

@GenerateMocks([YoutubeExplode, ChannelClient, Channel, ChannelId])
void main() {
  late MockYoutubeExplode mockYtClient;
  late MockChannelClient mockChannelClient;
  late MockChannel mockChannel;
  late MockChannelId mockChannelId;

  setUp(() {
    mockYtClient = MockYoutubeExplode();
    mockChannelClient = MockChannelClient();
    mockChannel = MockChannel();
    mockChannelId = MockChannelId();

    when(mockYtClient.channels).thenReturn(mockChannelClient);
  });

  group('YoutubeService.getChannelInfo URL Parsing Fallback Tests', () {
    test('Successful getByVideo resolution without fallback', () async {
      final url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

      when(mockChannelId.value).thenReturn('UC_x5XG1OV2P6uZZ5FSM9Ttw');
      when(mockChannel.id).thenReturn(mockChannelId);
      when(mockChannel.title).thenReturn('Rick Astley');
      when(mockChannel.logoUrl).thenReturn('https://example.com/logo.png');

      when(mockChannelClient.getByVideo(any)).thenAnswer((_) async => mockChannel);

      final result = await YoutubeService.getChannelInfo(url, ytClient: mockYtClient);

      expect(result, isNotNull);
      expect(result!.id, 'UC_x5XG1OV2P6uZZ5FSM9Ttw');
      expect(result.name, 'Rick Astley');
      expect(result.thumbnailUrl, 'https://example.com/logo.png');

      verify(mockChannelClient.getByVideo(url)).called(1);
      verifyNever(mockChannelClient.get(any));
    });

    test('Fallback to getChannelInfoById when getByVideo fails and URL contains /channel/', () async {
      final channelId = 'UC1234567890';
      final url = 'https://youtube.com/channel/$channelId?feature=share';

      when(mockChannelId.value).thenReturn(channelId);
      when(mockChannel.id).thenReturn(mockChannelId);
      when(mockChannel.title).thenReturn('Fallback Channel');
      when(mockChannel.logoUrl).thenReturn('https://example.com/fallback.png');

      // Simulate failure on getByVideo
      when(mockChannelClient.getByVideo(any)).thenThrow(ArgumentError('Invalid video URL'));

      // Simulate success on fallback get()
      when(mockChannelClient.get(channelId)).thenAnswer((_) async => mockChannel);

      final result = await YoutubeService.getChannelInfo(url, ytClient: mockYtClient);

      expect(result, isNotNull);
      expect(result!.id, channelId);
      expect(result.name, 'Fallback Channel');
      expect(result.thumbnailUrl, 'https://example.com/fallback.png');

      verify(mockChannelClient.getByVideo(url)).called(1);
      verify(mockChannelClient.get(channelId)).called(1);
    });

    test('Returns null when both getByVideo and fallback fail', () async {
      final channelId = 'UC1234567890';
      final url = 'https://youtube.com/channel/$channelId';

      when(mockChannelClient.getByVideo(any)).thenThrow(ArgumentError('Invalid video URL'));
      when(mockChannelClient.get(any)).thenThrow(Exception('Channel not found'));

      final result = await YoutubeService.getChannelInfo(url, ytClient: mockYtClient);

      expect(result, isNull);

      verify(mockChannelClient.getByVideo(url)).called(1);
      verify(mockChannelClient.get(channelId)).called(1);
    });

    test('Returns null when getByVideo fails and URL does not contain /channel/', () async {
      final url = 'https://youtube.com/user/SomeUser';

      when(mockChannelClient.getByVideo(any)).thenThrow(ArgumentError('Invalid video URL'));

      final result = await YoutubeService.getChannelInfo(url, ytClient: mockYtClient);

      expect(result, isNull);

      verify(mockChannelClient.getByVideo(url)).called(1);
      verifyNever(mockChannelClient.get(any));
    });
  });
}
