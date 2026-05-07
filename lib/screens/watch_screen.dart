import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:provider/provider.dart';
import '../core/tactile_widgets.dart';
import '../core/theme.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/channel_provider.dart';
import '../widgets/bedtime_overlay.dart';
import '../providers/usage_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../services/youtube_service.dart';
import '../services/download_service.dart';
import '../widgets/playtime_bucket.dart';
import '../services/video_cache_service.dart';
import '../core/app_localizations.dart';
import 'parental_gate.dart';
import 'package:audio_service/audio_service.dart';
import '../services/background_audio_service.dart';
import '../services/youtube_client_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../widgets/dadytube_controls.dart';

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
  yt.YoutubeExplode get _yt => YoutubeClientService().client;
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
  Orientation? _lastOrientation;
  bool _wasPlayingBeforeBreak = false;
  bool _isBreakCurrentlyActive = false;

  @override
  void initState() {
    super.initState();
    _videoTitle = widget.videoTitle; // Initialize with passed title
    WidgetsBinding.instance.addObserver(this);

    // Keep screen on during the watch session
    WakelockPlus.enable();

    // ✅ Enable all orientations while watching to allow sensor-based full-screen
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);

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
    // Start initializing the main player
    final initFuture = _initializePlayer();

    // Only set up preview if we are actually waiting for the network
    final localResults = await Future.wait([
      _downloadService.getLocalPath(widget.videoId),
      _cacheService.getCachedVideoPath(widget.videoId),
    ]);
    final hasLocal = (localResults[0] ?? localResults[1]) != null;

    if (!hasLocal) {
      final previewPath = await _cacheService.getPreviewPath(widget.videoId);
      if (previewPath != null && mounted) {
        // Double check existence one last time to avoid ENOENT race conditions
        final file = File(previewPath);
        if (await file.exists() && (await file.length()) > 0) {
          _previewController = VideoPlayerController.file(file);
          try {
            await _previewController!.initialize().timeout(
              const Duration(seconds: 3),
            );
            if (mounted && _isLoading) {
              // Only play preview if main player isn't ready
              _previewController!.setLooping(true);
              _previewController!.play();
              if (mounted) {
                setState(() {});
              }
            }
          } catch (_) {
            // Skip preview if codec fails
          }
        } else {
          _showGentleBuffer();
        }
      } else if (mounted && _isLoading) {
        // Show fallback buffer if no preview
        _showGentleBuffer();
      }
    } else {
      _showGentleBuffer();
    }
    await initFuture;
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

  void _setupChewieAndUI() {
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized)
      return;

    _videoPlayerController!.addListener(_onVideoProgress);

    final settings = Provider.of<SettingsProvider>(context, listen: false);

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: true,
      looping: false,
      fullScreenByDefault: settings.fullScreenByDefault,
      // Optimized aspect ratio: Use video ratio for portrait/standard,
      // but allow more fill in landscape to reduce black bars.
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      // Reduce black bars by attempting to fill screen in full screen mode
      optionsTranslation: OptionsTranslation(
        playbackSpeedButtonText: 'Speed',
        subtitlesButtonText: 'Subtitles',
        cancelButtonText: 'Cancel',
      ),
      placeholder:
          (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: widget.thumbnailUrl!,
              fit: BoxFit.cover,
            )
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
      showControls: true,
      customControls: const DadyTubeControls(),
      allowedScreenSleep: false,
      // ⚡ Reduced Black Bars: Apply custom scaling to the full-screen route
      routePageBuilder: (context, animation, secondaryAnimation, controllerProvider) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox.expand(
            child: Center(
              child: Transform.scale(
                scale: 1.1, // Zoom strictly at 1.1x as requested
                alignment: Alignment.center,
                child: controllerProvider,
              ),
            ),
          ),
        );
      },
    );

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
        _isShowingBuffer = false;
        if (_previewController != null) {
          _previewController!.pause();
          _previewController!.dispose();
          _previewController = null;
        }
      });
    }
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 1. Instant Metadata Lookup (Parallel)
      final channelProvider = context.read<ChannelProvider>();

      // Fire off metadata fetch and player init in parallel
      Future(() {
        final localVideo = channelProvider.getVideoById(widget.videoId);
        if (localVideo != null && mounted) {
          setState(() => _videoTitle = localVideo.title);
          return true;
        }
        return false;
      });

      // 2. Check local/cache sources (Priority #1)
      final localResults = await Future.wait([
        _downloadService.getLocalPath(widget.videoId),
        _cacheService.getCachedVideoPath(widget.videoId),
      ]);

      String? downloadPath = localResults[0];
      String? cachePath = localResults[1];
      String? finalLocalPath = downloadPath ?? cachePath;

      if (finalLocalPath != null) {
        print('🚀 Turbo Watch: Playing from Local/Cache File (INSTANT)');
        _videoPlayerController = VideoPlayerController.file(
          File(finalLocalPath),
        );

        await _videoPlayerController!.initialize().timeout(
          const Duration(seconds: 5),
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isShowingBuffer = false;
          });
        }

        _setupChewieAndUI();
        return; // EXIT EARLY - NO NETWORK NEEDED
      }

      final cachedUrl = await _cacheService.getCachedStreamUrl(widget.videoId);
      if (cachedUrl != null) {
        print('💎 Turbo Watch: Using Persistent Link Cache');
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(cachedUrl),
        );
      } else {
        // 4. Full Network Discovery (Slow Path)
        if (_videoTitle == null) {
          _yt.videos
              .get(widget.videoId)
              .then((v) {
                if (mounted) setState(() => _videoTitle = v.title);
              })
              .catchError((_) {});
        }

        if (!mounted) return;
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final manifest = await _cacheService.getManifest(widget.videoId);

        yt.MuxedStreamInfo streamInfo;
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

        _videoPlayerController = VideoPlayerController.networkUrl(streamInfo.url);

        // ⚡ Fix 7: Pass metadata so the .meta sidecar is written alongside the .mp4
        _cacheService.cacheVideo(
          widget.videoId,
          title: _videoTitle ?? widget.videoTitle ?? '',
          thumbnailUrl: widget.thumbnailUrl ?? '',
          channelId: widget.channelName ?? '',
        );

      }

      _videoPlayerController!.addListener(_onPlayerStateChanged);
      await _videoPlayerController!.initialize().timeout(
        const Duration(seconds: 10),
      );
      _setupChewieAndUI();
    } on yt.VideoUnplayableException catch (e) {
      if (!mounted) return;
      debugPrint('🚫 Interactive Recovery: Video unplayable - $e');
      setState(() {
        _isLoading = false;
        final errorStr = e.toString().toLowerCase();
        _errorMessage = errorStr.contains('bot')
            ? "Oh no! A robot blocked this toy. \nLet's try another one!"
            : "This toy is taking a nap. \nLet's find another one!";
      });
    } catch (e) {
      if (!mounted) return;

      // Attempt recovery
      final isFile =
          _videoPlayerController?.dataSourceType == DataSourceType.file;
      final isNetwork =
          _videoPlayerController?.dataSourceType == DataSourceType.network;

      if (isFile) {
        try {
          print(
            '⚠️ Watch Error: Corrupted local file. Deleting and falling back to network...',
          );
          final path = _videoPlayerController!.dataSource;
          // If the path starts with 'file://', we should strip it
          final cleanPath = path.startsWith('file://')
              ? path.substring(7)
              : path;
          final file = File(cleanPath);
          if (await file.exists()) {
            await file.delete();
            print('🗑️ Deleted corrupted file: $cleanPath');
          }

          // Fallback to network
          final manifest = await _cacheService.getManifest(widget.videoId);
          final freshStream = manifest.muxed.withHighestBitrate();
          if (freshStream != null) {
            _videoPlayerController = VideoPlayerController.networkUrl(
              freshStream.url,
            );
            await _videoPlayerController!.initialize().timeout(
              const Duration(seconds: 10),
            );
            _setupChewieAndUI();
            return;
          }
        } catch (e2) {
          print('⚠️ Local to Network recovery failed: $e2');
        }
      } else if (isNetwork) {
        try {
          print('⚠️ Watch Error: Network failure. Refreshing manifest...');
          final manifest = await _cacheService.getManifest(widget.videoId);
          final freshStream = manifest.muxed.withHighestBitrate();
          if (freshStream != null) {
            _videoPlayerController = VideoPlayerController.networkUrl(
              freshStream.url,
            );
            await _videoPlayerController!.initialize().timeout(
              const Duration(seconds: 10),
            );
            _setupChewieAndUI();
            return;
          }
        } catch (e2) {
          print('⚠️ Manifest recovery failed: $e2');
        }
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            "Oh no! This toy is currently taking a nap. \n(Error: ${e.toString()})";
      });
    }
  }

  void _skipToNextToy() {
    final provider = context.read<ChannelProvider>();
    final nextVideo = provider.getNextVideo(widget.videoId);
    if (nextVideo != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WatchScreen(
            videoId: nextVideo.id,
            videoTitle: nextVideo.title,
            thumbnailUrl: nextVideo.thumbnailUrl,
            channelName: "DadyTube Channel",
          ),
        ),
      );
    } else {
      Navigator.pop(context);
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
    // _yt.close(); // Shared singleton, don't close
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

    // Release the wake lock when exiting the player
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usage = Provider.of<UsageProvider>(context);
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // ✅ Auto-trigger Full-Screen & Breaks based on Orientation and Usage
    if (_chewieController != null &&
        _videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized) {
      // Only trigger on ACTUAL orientation change to avoid loop issues
      if (_lastOrientation != orientation) {
        debugPrint('🔄 Orientation changed: $_lastOrientation -> $orientation');
        if (isLandscape && !_chewieController!.isFullScreen) {
          debugPrint('📺 Entering Full Screen (Auto)');
          Future.microtask(() => _chewieController!.enterFullScreen());
        } else if (!isLandscape && _chewieController!.isFullScreen) {
          debugPrint('📱 Exiting Full Screen (Auto)');
          Future.microtask(() => _chewieController!.exitFullScreen());
        }
        _lastOrientation = orientation;
      }

      // 🧘 Mandatory Periodic Breaks (Eye Yoga)
      // We use a transition-based approach to ensure manual pauses are respected.
      if (usage.isBreakActive && !_isBreakCurrentlyActive) {
        // BREAK STARTED: Record state and pause
        debugPrint('🧘 Break Started: Pausing video');
        _isBreakCurrentlyActive = true;
        _wasPlayingBeforeBreak =
            _videoPlayerController?.value.isPlaying ?? false;
        if (_wasPlayingBeforeBreak) {
          _chewieController!.pause();
        }
      } else if (!usage.isBreakActive && _isBreakCurrentlyActive) {
        // BREAK ENDED: Auto-resume IF it was playing before
        debugPrint('🧘 Break Ended: Auto-resuming? $_wasPlayingBeforeBreak');
        _isBreakCurrentlyActive = false;
        if (_wasPlayingBeforeBreak) {
          _chewieController!.play();
        }
      }
    }

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

    // Instant Buttons logic: Always show the container to prevent layout shift.
    // We'll use the activeController if it exists, or dummy values if not.

    final activeController = hasPlayer
        ? ((_videoPlayerController != null &&
                  _videoPlayerController!.value.isInitialized)
              ? _videoPlayerController!
              : _previewController!)
        : null;

    final duration = activeController?.value.duration ?? Duration.zero;
    final position = activeController?.value.position ?? Duration.zero;
    final isPlaying = activeController?.value.isPlaying ?? false;

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
                    max: duration.inSeconds.toDouble() > 0
                        ? duration.inSeconds.toDouble()
                        : 1.0,
                    onChanged: (value) {
                      if (hasPlayer && _videoPlayerController != null) {
                        _videoPlayerController!.seekTo(
                          Duration(seconds: value.toInt()),
                        );
                      }
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
                onTap: hasPlayer
                    ? () {
                        final newPos = position - const Duration(seconds: 10);
                        activeController!.seekTo(
                          newPos < Duration.zero ? Duration.zero : newPos,
                        );
                      }
                    : null,
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
                onTap: hasPlayer
                    ? () {
                        if (isPlaying) {
                          activeController!.pause();
                        } else {
                          activeController!.play();
                        }
                        setState(() {});
                      }
                    : null,
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
                onTap: hasPlayer
                    ? () {
                        final newPos = position + const Duration(seconds: 10);
                        activeController!.seekTo(
                          newPos > duration ? duration : newPos,
                        );
                      }
                    : null,
                child: const TactileCard(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.forward_10_rounded,
                    color: DadyTubeTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Download Button (Textless icon next to Fullscreen)
              TactileButton(
                semanticLabel: 'Download for offline',
                onTap: _startDownload,
                child: const TactileCard(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.download_rounded, color: Colors.blueAccent),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sentiment_dissatisfied_rounded,
              size: 80,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _errorMessage ?? loc.translate('error_loading_video'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: DadyTubeTheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TactileButton(
                onTap: _initializePlayer,
                child: TactileCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        color: DadyTubeTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        loc.translate('try_again'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TactileButton(
                onTap: _skipToNextToy,
                child: TactileCard(
                  color: DadyTubeTheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.skip_next_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        "Try Next Toy",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
            Builder(
              builder: (context) {
                final provider = Provider.of<ChannelProvider>(
                  context,
                  listen: false,
                );
                final channel = provider.channels.firstWhere(
                  (c) =>
                      c.name == widget.channelName ||
                      c.thumbnailUrl == widget.channelThumbnailUrl,
                  orElse: () =>
                      YoutubeChannel(id: '', name: '', thumbnailUrl: ''),
                );

                if (channel.localThumbnailPath != null &&
                    File(channel.localThumbnailPath!).existsSync()) {
                  return CircleAvatar(
                    backgroundImage: FileImage(
                      File(channel.localThumbnailPath!),
                    ),
                    radius: 20,
                  );
                }

                if (widget.channelThumbnailUrl != null &&
                    widget.channelThumbnailUrl!.isNotEmpty) {
                  return CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(
                      widget.channelThumbnailUrl!,
                    ),
                    radius: 20,
                  );
                }

                return const CircleAvatar(
                  backgroundColor: DadyTubeTheme.primaryContainer,
                  radius: 20,
                  child: Icon(
                    Icons.person_rounded,
                    color: DadyTubeTheme.primary,
                  ),
                );
              },
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
        const SizedBox(height: 0),
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
    // Parent Gate removed per user request
    const authorized = true;

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
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 160,
                          width: 260,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        )
                      : Container(
                          height: 160,
                          width: 260,
                          color: DadyTubeTheme.primaryContainer,
                          child: const Icon(
                            Icons.play_circle_outline_rounded,
                            color: DadyTubeTheme.primary,
                            size: 48,
                          ),
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
    if (widget.thumbnailUrl == null || widget.thumbnailUrl!.isEmpty) {
      return Container(
        color: Colors.white.withOpacity(0.95),
        child: const Center(child: _PulseCloud()),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Blurred Background for Atmosphere
        CachedNetworkImage(
          imageUrl: widget.thumbnailUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.black),
        ),
        // Darken overlay
        Container(color: Colors.black.withOpacity(0.6)),

        // 2. High-Fidelity Focused Thumbnail
        Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'video_thumb_${widget.videoId}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: widget.thumbnailUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Subtle loading indicator
                const CircularProgressIndicator(
                  color: DadyTubeTheme.primary,
                  strokeWidth: 4,
                ),
                const SizedBox(height: 12),
                Text(
                  loc.translate('fetching_toys'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DadyTubeTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PulseCloud extends StatefulWidget {
  const _PulseCloud();

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
