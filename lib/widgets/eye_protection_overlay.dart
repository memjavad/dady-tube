import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/usage_provider.dart';
import '../core/theme.dart';
import '../core/app_localizations.dart';
import '../services/distance_protection_service.dart';

class EyeProtectionOverlay extends StatefulWidget {
  final Widget child;

  const EyeProtectionOverlay({super.key, required this.child});

  @override
  State<EyeProtectionOverlay> createState() => _EyeProtectionOverlayState();
}

class _EyeProtectionOverlayState extends State<EyeProtectionOverlay> {
  Timer? _filterUpdateTimer;
  bool _isTooClose = false;
  bool _isSlouching = false;
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
          _distanceSubscription = DistanceProtectionService().isTooCloseStream
              .listen((tooClose) {
                if (mounted && _isTooClose != tooClose) {
                  setState(() => _isTooClose = tooClose);
                }
              });

          _postureSubscription = DistanceProtectionService().isSlouchingStream
              .listen((slouching) {
                final postureEnabled = Provider.of<SettingsProvider>(
                  context,
                  listen: false,
                ).postureProtectionEnabled;
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
    _filterUpdateTimer?.cancel();
    _filterUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {}); // Rebuild to update blueLightIntensity
      }
    });
  }

  @override
  void dispose() {
    _filterUpdateTimer?.cancel();
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
          _BlueLightFilterOverlay(intensity: settings.blueLightIntensity),

        // --- Sunset Fadeout Overlay ---
        const _SunsetFadeoutOverlay(),

        // Break Overlay

        // Distance Warning Overlay (Step Back!)
        if (_isTooClose && settings.distanceProtectionEnabled)
          _DistanceWarningOverlay(loc: loc),

        // Posture Warning Overlay (Sit Up Straight!)
        if (_isSlouching && settings.postureProtectionEnabled)
          _PostureWarningOverlay(loc: loc),
      ],
    );
  }
}

class _BlueLightFilterOverlay extends StatelessWidget {
  final double intensity;

  const _BlueLightFilterOverlay({required this.intensity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(seconds: 3),
        curve: Curves.easeInOut,
        color: Colors.deepOrange.withOpacity(intensity * 0.25),
      ),
    );
  }
}

class _SunsetFadeoutOverlay extends StatelessWidget {
  const _SunsetFadeoutOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Consumer<UsageProvider>(
        builder: (context, usage, child) {
          final intensity = usage.sunsetIntensity;
          if (intensity <= 0) return const SizedBox.shrink();

          return Container(
            color: const Color(0xFF1A1A2E).withOpacity(intensity * 0.8),
          );
        },
      ),
    );
  }
}

class _DistanceWarningOverlay extends StatelessWidget {
  final AppLocalizations loc;

  const _DistanceWarningOverlay({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.85),
        child: BackdropFilter(
          filter: ColorFilter.mode(
            Colors.white.withOpacity(0.2),
            BlendMode.overlay,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 120,
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
                    child: const Icon(
                      Icons.visibility_off_rounded,
                      size: 60,
                      color: Colors.pinkAccent,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.15),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/bad_posture_rabbit.png',
                          height: 240,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const Positioned(
                        top: 20,
                        right: 20,
                        child: Icon(
                          Icons.cancel_rounded,
                          color: Colors.redAccent,
                          size: 80,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 40,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          loc.translate('step_back_title'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w800,
                            color: DadyTubeTheme.primary,
                            fontSize: 24,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.translate('safety_pause'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
      ),
    );
  }
}

class _PostureWarningOverlay extends StatelessWidget {
  final AppLocalizations loc;

  const _PostureWarningOverlay({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.1),
                                blurRadius: 60,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/bad_posture_rabbit.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.2),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.redAccent,
                            size: 80,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.accessibility_new_rounded,
                        color: DadyTubeTheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        loc.translate('sit_up_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: DadyTubeTheme.primary,
                          fontSize: 18,
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
    );
  }
}
