import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

class BackgroundAudioService extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  final yt.YoutubeExplode _yt;

  BackgroundAudioService({AudioPlayer? player, yt.YoutubeExplode? ytExplode})
    : _player = player ?? AudioPlayer(),
      _yt = ytExplode ?? yt.YoutubeExplode() {
    // Broadcast playback state changes
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Starts playing the audio stream of a YouTube video.
  Future<void> playVideo(
    String videoId,
    String title,
    String artist,
    String? thumbnailUrl,
  ) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStream = manifest.audioOnly.withHighestBitrate();

      if (audioStream == null) return;

      // Update MediaItem for the notification
      mediaItem.add(
        MediaItem(
          id: videoId,
          album: "DadyTube Play",
          title: title,
          artist: artist,
          artUri: thumbnailUrl != null ? Uri.parse(thumbnailUrl) : null,
          duration: null, // JustAudio will update this once loaded
        ),
      );

      await _player.setAudioSource(AudioSource.uri(audioStream.url));
      _player.play();
    } catch (e) {
      debugPrint('Background Audio Error: $e');
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  void dispose() {
    _player.dispose();
    _yt.close();
  }
}
