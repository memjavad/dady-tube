import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/tactile_widgets.dart';
import '../core/theme.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/channel_provider.dart';
import '../widgets/bedtime_overlay.dart';
import '../providers/usage_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../services/youtube_service.dart';
import '../services/download_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/eye_protection_overlay.dart';
import '../widgets/playtime_bucket.dart';
import '../services/video_cache_service.dart';
import '../core/app_localizations.dart';
import 'parental_gate.dart';
import 'package:audio_service/audio_service.dart';
import '../services/background_audio_service.dart';

class WatchScreen extends StatefulWidget {
  final String videoId;
  final String? videoTitle; // New parameter
  final String? thumbnailUrl;
  final String? channelName;
  final String? channelThumbnailUrl;

  const WatchScreen({
    super.key,
    required this.videoId,
    this.videoTitle, // New parameter
    this.thumbnailUrl,
    this.channelName,
    this.channelThumbnailUrl,
  });

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> with WidgetsBindingObserver {
  late yt.YoutubeExplode _yt;
  VideoPlayerController? _videoPlayerController;
  VideoPlayerController? _previewController;
  ChewieController? _chewieController;
  final DownloadService _downloadService = DownloadService();
  final VideoCacheService _cacheService = VideoCacheService();
  bool _isLoading = true;
  String? _errorMessage;
  double _downloadProgress = 0;
  bool _isDownloading = false;
  bool _isFinished = false;
  bool _isShowingBuffer = false;
  bool _isPlaying = false;
  bool _isBackgroundPlaying = false;
  String? _videoTitle;

  @override
  void initState() {
    super.initState();
    _yt = yt.YoutubeExplode();
    _videoTitle = widget.videoTitle; // Initialize with passed title
    WidgetsBinding.instance.addObserver(this);

    // ⚡ Performance Prioritization: Pause background tasks immediately
    // to give the video player 100% of device resources.
    _cacheService.pauseBackgroundOperations();

    // Phase 2: Show Gentle Buffer before initializing player
    _setupPreviewAndInitialize();

    // Safety timeout: Re-enable background tasks if video fails to play within 15s
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        _cacheService.resumeBackgroundOperations();
      }
    });
  }

  void _onPlayerStateChanged() {
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized &&
        _videoPlayerController!.value.isPlaying &&
        !_videoPlayerController!.value.isBuffering) {
      // 🚀 Video is playing smoothly. Resume background processes.
      _cacheService.resumeBackgroundOperations();
      // Keep listener for buffering changes if needed, but for now we just want the initial resume.
      _videoPlayerController!.removeListener(_onPlayerStateChanged);
    }
  }

  Future<void> _setupPreviewAndInitialize() async {
    // Start initializing the main player in parallel with the preview
    _initializePlayer();

    final previewPath = await _cacheService.getPreviewPath(widget.videoId);
    if (previewPath != null && mounted) {
      _previewController = VideoPlayerController.file(File(previewPath));
      await _previewController!.initialize();
      if (mounted && _isLoading) {
        // Only play preview if main player isn't ready
        _previewController!.setLooping(true);
        if (mounted) {
          setState(() {});
        }
      }
    } else if (mounted && _isLoading) {
      // Show fallback buffer if no preview
      _showGentleBuffer();
    }
  }

  Future<void> _showGentleBuffer() async {
    if (mounted) {
      setState(() => _isShowingBuffer = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _maybeStartBackgroundPlayback();
    } else if (state == AppLifecycleState.resumed) {
      _maybeStopBackgroundPlayback();
    }
  }

  void _maybeStartBackgroundPlayback() {
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.isPlaying) {
      final position = _videoPlayerController!.value.position;
      _videoPlayerController!.pause();

      final audioHandler =
          context.read<AudioHandler>() as BackgroundAudioService;
      audioHandler
          .playVideo(
            widget.videoId,
            _videoTitle ?? "DadyTube",
            "DadyTube",
            widget.thumbnailUrl,
          )
          .then((_) {
            if (mounted) {
              audioHandler.seek(position);
              setState(() => _isBackgroundPlaying = true);
            }
          });
    }
  }

  void _maybeStopBackgroundPlayback() {
    if (_isBackgroundPlaying) {
      final audioHandler =
          context.read<AudioHandler>() as BackgroundAudioService;
      final position = audioHandler.playbackState.value.position;

      audioHandler.pause();
      audioHandler.stop();

      if (_videoPlayerController != null) {
        _videoPlayerController!.seekTo(position);
        _videoPlayerController!.play();
      }

      if (mounted) {
        setState(() => _isBackgroundPlaying = false);
      }
    }
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Defer background sync until video is actually playing smoothly
      // context.read<ChannelProvider>().triggerBackgroundSync();

      // Fetch video title for background notification
      _yt.videos.get(widget.videoId).then((v) {
        if (mounted) setState(() => _videoTitle = v.title);
      });

      // 1 & 2. Check local/cache sources in parallel
      final localResults = await Future.wait([
        _downloadService.getLocalPath(widget.videoId),
        _cacheService.getCachedVideoPath(widget.videoId),
        _cacheService.getCachedStreamUrl(widget.videoId),
      ]);

      String? downloadPath = localResults[0];
      String? cachePath = localResults[1];
      String? cachedUrl = localResults[2];

      if (downloadPath != null || cachePath != null) {
        print('🚀 Turbo Watch: Playing from Local/Cache File');
        _videoPlayerController = VideoPlayerController.file(
          File(downloadPath ?? cachePath!),
        );
      } else if (cachedUrl != null) {
        print('💎 Turbo Watch: Using Persistent Link Cache (Instant Play!)');
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(cachedUrl),
        );
      } else {
        // 3. Play from network (Bypass Mode)
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final manifest = await _cacheService.getManifest(widget.videoId);

        yt.MuxedStreamInfo? streamInfo;
        final isTurbo = settings.turboModeEnabled;
        final quality = isTurbo ? VideoQuality.p360 : settings.videoQuality;

        if (quality == VideoQuality.auto && !isTurbo) {
          streamInfo = manifest.muxed.withHighestBitrate();
        } else {
          int targetWidth = (quality == VideoQuality.p360)
              ? 640
              : (quality == VideoQuality.p720 ? 1280 : 1920);
          final compatibleStreams = manifest.muxed
              .where((s) => s.videoResolution.width <= targetWidth)
              .toList();
          streamInfo = compatibleStreams.isNotEmpty
              ? compatibleStreams.withHighestBitrate()
              : manifest.muxed.withHighestBitrate();
        }

        if (streamInfo == null) throw Exception("No playable stream found.");
        _videoPlayerController = VideoPlayerController.networkUrl(
          streamInfo.url,
        );

        // Bonus: Start caching this video in background
        _cacheService.cacheVideo(widget.videoId);
      }
      try {
        _videoPlayerController!.addListener(_onPlayerStateChanged);
        await _videoPlayerController!.initialize();
      } catch (e) {
        // If it was a cached URL, it might have expired. Try one more time with fresh manifest.
        final cachedUrl = await _cacheService.getCachedStreamUrl(
          widget.videoId,
        );
        if (cachedUrl != null) {
          print('⚠️ V3.4: Cached URL expired or failed. Refreshing...');
          // Invalidate cache
          final prefs = await SharedPreferences.getInstance();
          final jsonStr = prefs.getString('persistent_stream_urls') ?? '{}';
          final Map<String, dynamic> data = json.decode(jsonStr);
          data.remove(widget.videoId);
          await prefs.setString('persistent_stream_urls', json.encode(data));

          // Fetch fresh and re-initialize
          final manifest = await _cacheService.getManifest(widget.videoId);
          final freshStream = manifest.muxed.withHighestBitrate();
          if (freshStream != null) {
            _videoPlayerController = VideoPlayerController.networkUrl(
              freshStream.url,
            );
            _videoPlayerController!.addListener(_onPlayerStateChanged);
            await _videoPlayerController!.initialize();
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      _videoPlayerController!.addListener(_onVideoProgress);

      final settings = Provider.of<SettingsProvider>(context, listen: false);

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        fullScreenByDefault: settings.fullScreenByDefault,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        placeholder: widget.thumbnailUrl != null
            ? Image.network(widget.thumbnailUrl!, fit: BoxFit.cover)
            : const Center(
                child: CircularProgressIndicator(color: DadyTubeTheme.primary),
              ),
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primaryContainer,
          bufferedColor: Theme.of(
            context,
          ).colorScheme.primaryContainer.withOpacity(0.3),
          backgroundColor: Colors.grey.withOpacity(0.2),
        ),
        // Design Sandbox rules: Customizing controls
        showControls: true,
        customControls: const MaterialControls(),
      );

      // Fix for Full-Screen Exit: Ensure orientation resets properly
      _chewieController!.addListener(() {
        if (!_chewieController!.isFullScreen) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: SystemUiOverlay.values,
          );
        }
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isShowingBuffer = false; // Hide buffer once ready
          // Clean up preview player to prevent "ghosting" or PiP overlaps
          if (_previewController != null) {
            _previewController!.pause();
            _previewController!.dispose();
            _previewController = null;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            "Oh no! This toy is currently taking a nap. \n(Error: ${e.toString()})";
      });
    }
  }

  void _onVideoProgress() {
    if (!mounted) return;
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized) {
      final position = _videoPlayerController!.value.position;
      final duration = _videoPlayerController!.value.duration;
      final isPlayingNow = _videoPlayerController!.value.isPlaying;

      if (_isPlaying != isPlayingNow) {
        setState(() => _isPlaying = isPlayingNow);
      } else {
        // Still need to rebuild to update the progress slider
        setState(() {});
      }

      if (position >= duration && !_isFinished) {
        setState(() {
          _isFinished = true;
        });

        // Predictive Pre-warming: Prepare the next video while this one plays
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<ChannelProvider>().prewarmNextVideo(widget.videoId);
          }
        });

        // Phase 4: Grant Stars for educational content
        final title = (_videoTitle ?? widget.videoTitle ?? "").toLowerCase();
        final isEducational =
            title.contains('learn') ||
            title.contains('story') ||
            title.contains('abc') ||
            title.contains('math') ||
            title.contains('number');

        if (isEducational) {
          context.read<UsageProvider>().addStar();
        }
      }
    }
  }

  @override
  void dispose() {
    // ⚡ Reset background state if we exit mid-buffer
    _cacheService.resumeBackgroundOperations();
    _videoPlayerController?.removeListener(_onPlayerStateChanged);
    _videoPlayerController?.removeListener(_onVideoProgress);

    WidgetsBinding.instance.removeObserver(this);
    _yt.close();
    _downloadService.dispose();

    // Safety Reset for System UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    _videoPlayerController?.dispose();
    _previewController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final showImmersive = isLandscape || (_isPlaying && !_isShowingBuffer);

    return BedtimeOverlay(
      child: Container(
        color: Theme.of(context)
            .colorScheme
            .background, // Ensure solid background even if Scaffold has issues
        child: Scaffold(
          backgroundColor:
              Colors.transparent, // Let Container provide the solid color
          body: Stack(
            children: [
              Column(
                children: [
                  SizedBox(
                    height: isLandscape
                        ? 0
                        : MediaQuery.of(context).padding.top,
                  ),
                  if (isLandscape)
                    Expanded(child: _buildPlayerArea(context))
                  else
                    _buildPlayerArea(context),

                  if (!isLandscape) _buildTactileControls(context),

                  // Keep metadata visible but maybe dimmed in portrait
                  if (!isLandscape)
                    Expanded(
                      child: Opacity(
                        opacity:
                            1.0, // Fixed opacity to prevent dimming during play
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildVideoInfo(context),
                              const SizedBox(height: 32),
                              _buildActions(context),
                              if (Provider.of<SettingsProvider>(
                                context,
                              ).showSuggestions) ...[
                                const SizedBox(height: 48),
                                _buildWatchMore(context),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Hide PlaytimeBucket when video is playing for a fully immersive look
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                bottom:
                    MediaQuery.of(context).padding.bottom +
                    24, // Keep visible even when playing
                left: 24,
                right: 24,
                child: const PlaytimeBucket(size: 80),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConclusionOverlay(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      color: Colors.white.withOpacity(0.95),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.stars_rounded,
              size: 80,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 24),
            Text(
              loc.translate('video_finished'),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: DadyTubeTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loc.translate('ready_for_break'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            TactileButton(
              onTap: () => Navigator.pop(context),
              child: TactileCard(
                color: DadyTubeTheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                child: Text(
                  loc.translate('go_home'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerArea(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: _errorMessage != null
            ? _buildErrorState(context)
            : _chewieController != null
            ? Stack(
                children: [
                  Chewie(controller: _chewieController!),
                  if (_isFinished) _buildConclusionOverlay(context),
                ],
              )
            : (_previewController != null &&
                  _previewController!.value.isInitialized)
            ? VideoPlayer(_previewController!)
            : _buildGentleBuffer(context),
      ),
    );
  }

  Widget _buildTactileControls(BuildContext context) {
    final hasPlayer =
        (_videoPlayerController != null &&
            _videoPlayerController!.value.isInitialized) ||
        (_previewController != null && _previewController!.value.isInitialized);

    if (!hasPlayer) {
      return const SizedBox.shrink();
    }

    final activeController =
        (_videoPlayerController != null &&
            _videoPlayerController!.value.isInitialized)
        ? _videoPlayerController!
        : _previewController!;

    final duration = activeController.value.duration;
    final position = activeController.value.position;
    final isPlaying = activeController.value.isPlaying;

    String formatDuration(Duration d) {
      final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return "$minutes:$seconds";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress Bar
          Row(
            children: [
              Text(
                formatDuration(position),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 12,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    activeTrackColor: DadyTubeTheme.primary,
                    inactiveTrackColor: DadyTubeTheme.primary.withOpacity(0.1),
                    thumbColor: DadyTubeTheme.primary,
                  ),
                  child: Slider(
                    value: position.inSeconds.toDouble(),
                    max: duration.inSeconds.toDouble(),
                    onChanged: (value) {
                      _videoPlayerController!.seekTo(
                        Duration(seconds: value.toInt()),
                      );
                    },
                  ),
                ),
              ),
              Text(
                formatDuration(duration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TactileButton(
                semanticLabel: 'Rewind 10 seconds',
                onTap: () {
                  final newPos = position - const Duration(seconds: 10);
                  activeController.seekTo(
                    newPos < Duration.zero ? Duration.zero : newPos,
                  );
                },
                child: const TactileCard(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.replay_10_rounded,
                    color: DadyTubeTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              TactileButton(
                semanticLabel: isPlaying ? 'Pause' : 'Play',
                onTap: () {
                  if (isPlaying) {
                    activeController.pause();
                  } else {
                    activeController.play();
                  }
                  setState(() {});
                },
                child: TactileCard(
                  color: DadyTubeTheme.primary,
                  padding: const EdgeInsets.all(16),
                  shape: const StadiumBorder(),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              TactileButton(
                semanticLabel: 'Fast forward 10 seconds',
                onTap: () {
                  final newPos = position + const Duration(seconds: 10);
                  activeController.seekTo(
                    newPos > duration ? duration : newPos,
                  );
                },
                child: const TactileCard(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.forward_10_rounded,
                    color: DadyTubeTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              TactileButton(
                semanticLabel: 'Enter Fullscreen',
                onTap: () {
                  if (_chewieController != null) {
                    _chewieController!.enterFullScreen();
                  }
                },
                child: const TactileCard(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.fullscreen_rounded,
                    color: DadyTubeTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.toys_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? loc.translate('error_loading_video'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          TactileButton(
            onTap: _initializePlayer,
            child: TactileCard(
              color: DadyTubeTheme.primary,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Text(
                  loc.translate('try_again'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInfo(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _videoTitle ?? loc.translate('play'),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            if (widget.channelThumbnailUrl != null)
              CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(
                  widget.channelThumbnailUrl!,
                ),
                radius: 20,
              )
            else
              const CircleAvatar(
                backgroundColor: DadyTubeTheme.primaryContainer,
                radius: 20,
                child: Icon(Icons.person_rounded, color: DadyTubeTheme.primary),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.channelName ?? "DadyTube Channel",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    loc.translate('popular_now'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Column(
      children: [
        if (_isDownloading)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TactileCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: DadyTubeTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.translate('downloading_travel'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _downloadProgress,
                              color: DadyTubeTheme.primary,
                              backgroundColor: DadyTubeTheme.primary
                                  .withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TactileButton(
                onTap: () {},
                child: TactileCard(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFFF5C5C),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        loc.translate('save'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TactileButton(
                onTap: _startDownload,
                child: TactileCard(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.download_rounded,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        loc.translate('download'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TactileButton(
          onTap: () => Navigator.pop(context),
          child: TactileCard(
            color: Theme.of(context).cardTheme.color,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.home_rounded, color: DadyTubeTheme.primary),
                const SizedBox(width: 12),
                Text(
                  loc.translate('go_home'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startDownload() async {
    final loc = AppLocalizations.of(context);
    // Parent Gate
    final authorized = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const ParentalGate(destination: _AuthorizedDownload()),
      ),
    );

    if (authorized == true) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0;
      });

      try {
        await _downloadService.downloadVideo(widget.videoId, (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        });

        // Register metadata for offline browsing
        final channelProvider = Provider.of<ChannelProvider>(
          context,
          listen: false,
        );
        final downloadProvider = Provider.of<DownloadProvider>(
          context,
          listen: false,
        );

        final video = channelProvider.allVideos.firstWhere(
          (v) => v.id == widget.videoId,
          orElse: () => YoutubeVideo(
            id: widget.videoId,
            title: 'Downloaded Video',
            thumbnailUrl: widget.thumbnailUrl ?? '',
            channelId: '',
            publishedAt: DateTime.now(),
          ),
        );

        await downloadProvider.addDownloadedVideo(video);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('added_to_travel'))),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.translate('download_failed')}: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
        }
      }
    }
  }

  Widget _buildWatchMore(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final provider = context.watch<ChannelProvider>();
    final moreVideos = provider.allVideos.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              loc.translate('watch_more'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TactileButton(
              onTap: () {},
              child: Text(
                loc.translate('view_all'),
                style: const TextStyle(
                  color: DadyTubeTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...moreVideos.map(
          (video) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildVideoListItem(
              context,
              video.title,
              video.thumbnailUrl,
              videoId: video.id,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoListItem(
    BuildContext context,
    String title,
    String imageUrl, {
    String videoId = 'L_LUpnjyPso',
  }) {
    return TactileButton(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WatchScreen(
              videoId: videoId,
              thumbnailUrl: imageUrl,
              channelName: "DadyTube Channel", // Ideally we'd have this data
            ),
          ),
        );
      },
      child: TactileCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 32,
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 160,
                    width: 260,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGentleBuffer(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      color: Colors.white.withOpacity(0.95),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _PulseCloud(),
            const SizedBox(height: 16),
            Text(
              loc.translate('breathe_in'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DadyTubeTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorizedDownload extends StatelessWidget {
  const _AuthorizedDownload();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.download_rounded,
              size: 64,
              color: DadyTubeTheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              loc.translate('download_confirm'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(loc.translate('download_msg'), textAlign: TextAlign.center),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TactileButton(
                  onTap: () => Navigator.pop(context, false),
                  child: TactileCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(loc.translate('cancel')),
                  ),
                ),
                const SizedBox(width: 24),
                TactileButton(
                  onTap: () => Navigator.pop(context, true),
                  child: TactileCard(
                    color: DadyTubeTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    child: Text(
                      loc.translate('yes_download'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseCloud extends StatefulWidget {
  const _PulseCloud({super.key});

  @override
  State<_PulseCloud> createState() => _PulseCloudState();
}

class _PulseCloudState extends State<_PulseCloud>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: const Icon(
        Icons.cloud_rounded,
        size: 80,
        color: Colors.blueAccent,
      ),
    );
  }
}
