import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/usage_provider.dart';
import '../core/theme.dart';
import '../core/app_localizations.dart';
import '../core/tactile_widgets.dart';
import '../services/distance_protection_service.dart';

class EyeProtectionOverlay extends StatefulWidget {
  final Widget child;

  const EyeProtectionOverlay({super.key, required this.child});

  @override
  State<EyeProtectionOverlay> createState() => _EyeProtectionOverlayState();
}

class _EyeProtectionOverlayState extends State<EyeProtectionOverlay> {
  Timer? _breakTimer;
  Timer? _activityTimer;
  bool _showOverlay = false;
  bool _isTooClose = false;
  bool _isSlouching = false;
  int _currentActivity = 0;
  StreamSubscription<bool>? _distanceSubscription;
  StreamSubscription<bool>? _postureSubscription;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _initDistanceProtection();
  }

  void _initDistanceProtection() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.distanceProtectionEnabled) {
      DistanceProtectionService().initialize().then((_) {
        if (mounted) {
          _distanceSubscription = DistanceProtectionService().isTooCloseStream.listen((tooClose) {
            if (mounted && _isTooClose != tooClose) {
              setState(() => _isTooClose = tooClose);
            }
          });

          _postureSubscription = DistanceProtectionService().isSlouchingStream.listen((slouching) {
            final postureEnabled = Provider.of<SettingsProvider>(context, listen: false).postureProtectionEnabled;
            if (mounted && _isSlouching != (slouching && postureEnabled)) {
              setState(() => _isSlouching = slouching && postureEnabled);
            }
          });
        }
      });
    }
  }

  void _stopDistanceProtection() {
    _distanceSubscription?.cancel();
    _postureSubscription?.cancel();
    DistanceProtectionService().dispose();
  }

  void _startTimer() {
    _breakTimer?.cancel();
    _breakTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.restRemindersEnabled && !settings.bedtimeMode) {
        _showBreak();
      }
    });
  }

  void _showBreak() {
    setState(() {
      _showOverlay = true;
      _currentActivity = 0;
    });
    
    // Cycle through 3 activities every 7 seconds
    _activityTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (mounted && _showOverlay) {
        setState(() {
          if (_currentActivity < 2) {
            _currentActivity++;
          } else {
            timer.cancel();
            _hideBreak();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _hideBreak() {
    if (mounted) {
      setState(() => _showOverlay = false);
    }
    _activityTimer?.cancel();
  }

  @override
  void dispose() {
    _breakTimer?.cancel();
    _activityTimer?.cancel();
    _stopDistanceProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final loc = AppLocalizations.of(context);
    
    return Stack(
      children: [
        widget.child,
        // Optimized Blue Light Filter (Lightweight Overlay)
        if (settings.eyeProtectionEnabled)
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(seconds: 3),
              curve: Curves.easeInOut,
              color: Colors.deepOrange.withOpacity(settings.blueLightIntensity * 0.25),
            ),
          ),
        
        // --- Sunset Fadeout Overlay ---
        IgnorePointer(
          child: Consumer<UsageProvider>(
            builder: (context, usage, child) {
              final intensity = usage.sunsetIntensity;
              if (intensity <= 0) return const SizedBox.shrink();
              
              return Container(
                color: const Color(0xFF1A1A2E).withOpacity(intensity * 0.8),
              );
            },
          ),
        ),
        
        // Break Overlay
        if (_showOverlay)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.98),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.spa_rounded, color: DadyTubeTheme.primary, size: 60),
                      const SizedBox(height: 32),
                      const SizedBox(height: 48),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: _buildActivityCard(context, _currentActivity, loc),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildProgressBar(),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Distance Warning Overlay (Step Back!)
        if (_isTooClose && settings.distanceProtectionEnabled)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.85),
              child: BackdropFilter(
                filter: ColorFilter.mode(Colors.white.withOpacity(0.2), BlendMode.overlay),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: DadyTubeTheme.primary.withOpacity(0.2),
                                blurRadius: 32,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: Image.file(
                            File('C:/Users/memja/.gemini/antigravity/brain/98245db2-aa35-43b2-8914-926aaa5807db/step_back_bunny_3d_1774629347285.png'),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.pinkAccent),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Image.file(
                          File('C:/Users/memja/.gemini/antigravity/brain/98245db2-aa35-43b2-8914-926aaa5807db/bunny_distance_guide_3d_1774629473626.png'),
                          height: 280,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.straighten_rounded, color: DadyTubeTheme.primary),
                                  const SizedBox(width: 12),
                                  Text(
                                    loc.translate('step_back_title'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: DadyTubeTheme.primary, fontSize: 18),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loc.translate('safety_pause'),
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Posture Warning Overlay (Sit Up Straight!)
        if (_isSlouching && settings.postureProtectionEnabled)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.92),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: DadyTubeTheme.primary.withOpacity(0.1),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/rabbit_posture_3d.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.accessibility_new_rounded, color: DadyTubeTheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              loc.translate('sit_up_title'),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: DadyTubeTheme.primary, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (_currentActivity + 1) / 3,
            backgroundColor: DadyTubeTheme.primary.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation(DadyTubeTheme.primary),
            minHeight: 12,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "${_currentActivity + 1} / 3",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildActivityCard(BuildContext context, int index, AppLocalizations loc) {
    final activities = [
      {
        'image': 'assets/images/eye_yoga_look_far.png',
        'color': Colors.blueAccent,
      },
      {
        'image': 'assets/images/eye_yoga_blink.png',
        'color': Colors.orangeAccent,
      },
      {
        'image': 'assets/images/eye_yoga_stretch.png',
        'color': Colors.purpleAccent,
      },
    ];

    final activity = activities[index];

    return Column(
      key: ValueKey(index),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(48),
              boxShadow: [
                BoxShadow(
                  color: (activity['color'] as Color).withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(48),
              child: Image.asset(
                activity['image'] as String,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Wordless Design Sandbox: Removing explicit text instructions to let the UI breathe
        // and allow children to simply copy the "Virtual Buddy" rabbit.
      ],
    );
  }
}
