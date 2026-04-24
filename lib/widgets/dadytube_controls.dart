import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import '../core/tactile_widgets.dart';
import '../core/theme.dart';

class DadyTubeControls extends StatefulWidget {
  const DadyTubeControls({super.key});

  @override
  State<DadyTubeControls> createState() => _DadyTubeControlsState();
}

class _DadyTubeControlsState extends State<DadyTubeControls> {
  bool _hideStuff = true;
  Timer? _hideTimer;
  VideoPlayerController? _controller;
  ChewieController? _chewieController;

  @override
  void didChangeDependencies() {
    final oldController = _chewieController;
    _chewieController = ChewieController.of(context);
    _controller = _chewieController!.videoPlayerController;

    if (oldController != _chewieController) {
      _cancelAndRestartTimer();
    }

    super.didChangeDependencies();
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    setState(() {
      _hideStuff = false;
    });
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _hideStuff = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  Widget _buildPlayPause(VideoPlayerValue value, double scale) {
    final isFinished = value.position >= value.duration;
    final isPlaying = value.isPlaying;

    return TactileButton(
      semanticLabel: isPlaying ? 'Pause' : (isFinished ? 'Replay' : 'Play'),
      onTap: () {
        _cancelAndRestartTimer();
        if (isPlaying) {
          _controller!.pause();
        } else {
          if (isFinished) {
            _controller!.seekTo(Duration.zero);
          }
          _controller!.play();
        }
      },
      child: TactileCard(
        color: DadyTubeTheme.primary,
        shape: const StadiumBorder(),
        padding: EdgeInsets.all(24 * scale),
        child: Icon(
          isFinished
              ? Icons.replay_rounded
              : (isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          color: Colors.white,
          size: 48 * scale,
        ),
      ),
    );
  }

  Widget _buildSkip(bool forward, double scale) {
    return TactileButton(
      semanticLabel: forward ? 'Fast forward 10 seconds' : 'Rewind 10 seconds',
      onTap: () {
        _cancelAndRestartTimer();
        final currentPosition = _controller!.value.position;
        final newPosition = forward
            ? currentPosition + const Duration(seconds: 10)
            : currentPosition - const Duration(seconds: 10);
        _controller!.seekTo(newPosition);
      },
      child: TactileCard(
        color: Colors.white.withOpacity(0.8),
        shape: const CircleBorder(),
        padding: EdgeInsets.all(16 * scale),
        child: Icon(
          forward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
          color: DadyTubeTheme.primary,
          size: 32 * scale,
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context, double scale) {
    return TactileButton(
      onTap: () {
        if (_chewieController!.isFullScreen) {
          _chewieController!.exitFullScreen();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: TactileCard(
        color: DadyTubeTheme.primary,
        shape: const CircleBorder(),
        padding: EdgeInsets.all(12 * scale),
        child: Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 28 * scale,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || _chewieController == null)
      return const SizedBox();

    // ✅ Strengthened full-screen detection
    final isFullScreen =
        _chewieController!.isFullScreen ||
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Scale up buttons for kids in full screen (compensated for 1.1x video zoom)
    final scale = isFullScreen ? (2.0 / 1.1) : 1.0;

    return Stack(
      children: [
        // 1️⃣ Background toggle: Catches taps anywhere that *miss* a button
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _hideStuff = !_hideStuff;
            });
            if (!_hideStuff) {
              _cancelAndRestartTimer();
            }
          },
          child: const SizedBox.expand(),
        ),

        // 2️⃣ Actual Controls Layer
        IgnorePointer(
          ignoring: _hideStuff,
          child: AnimatedOpacity(
            opacity: _hideStuff ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: Stack(
              children: [
                // Dark background overlay when controls are visible (softened)
                if (!_hideStuff)
                  IgnorePointer(
                    child: Container(color: Colors.black.withAlpha(76)),
                  ),

                // ✅ Responsive Controls using SafeArea with Zoom Compensation
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      // Increase padding in full screen to account for 1.1x scaling which pushes
                      // logical edges off-screen by roughly 5% on each side.
                      horizontal: (isFullScreen ? 64.0 : 16.0) * scale,
                      vertical: (isFullScreen ? 48.0 : 16.0) * scale,
                    ),
                    child: Stack(
                      children: [
                        // Back Button (Only visible in Full Screen as requested)
                        if (isFullScreen)
                          Positioned(
                            top: 0,
                            left: 0,
                            child: TactileButton(
                              semanticLabel: 'Back',
                              onTap: () {
                                if (_chewieController!.isFullScreen) {
                                  _chewieController!.exitFullScreen();
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),

                        // Central Controls
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSkip(false, scale),
                              SizedBox(width: 32 * scale),
                              ValueListenableBuilder(
                                valueListenable: _controller!,
                                builder:
                                    (context, VideoPlayerValue value, child) {
                                      return _buildPlayPause(value, scale);
                                    },
                              ),
                              SizedBox(width: 32 * scale),
                              _buildSkip(true, scale),
                            ],
                          ),
                        ),

                        // Progress Bar (Bottom - pushed to edge to avoid overlap with buttons)
                        Positioned(
                          bottom: (isFullScreen ? 12.0 : 4.0) * scale,
                          left: 16 * scale,
                          right: 16 * scale,
                          child: ValueListenableBuilder(
                            valueListenable: _controller!,
                            builder: (context, VideoPlayerValue value, child) {
                              final position = value.position;
                              final duration = value.duration;

                              return SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 12 * scale,
                                  thumbShape: RoundSliderThumbShape(
                                    enabledThumbRadius: 10 * scale,
                                  ),
                                  activeTrackColor: DadyTubeTheme.primary,
                                  inactiveTrackColor: Colors.white.withAlpha(
                                    204,
                                  ),
                                  thumbColor: DadyTubeTheme.primary,
                                  overlayColor: DadyTubeTheme.primary
                                      .withOpacity(0.2),
                                ),
                                child: Slider(
                                  value: position.inMilliseconds.toDouble(),
                                  max: duration.inMilliseconds.toDouble() > 0
                                      ? duration.inMilliseconds.toDouble()
                                      : 1.0,
                                  onChanged: (val) {
                                    _cancelAndRestartTimer();
                                    _controller!.seekTo(
                                      Duration(milliseconds: val.toInt()),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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
