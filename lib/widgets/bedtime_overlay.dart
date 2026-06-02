import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'animated_bedtime_moon.dart';
import 'falling_stars_background.dart';
import '../providers/usage_provider.dart';
import '../providers/settings_provider.dart';
import '../core/tactile_widgets.dart';
import '../screens/parental_gate.dart';
import '../core/app_localizations.dart';

class BedtimeOverlay extends StatefulWidget {
  final Widget child;
  const BedtimeOverlay({super.key, required this.child});

  @override
  State<BedtimeOverlay> createState() => _BedtimeOverlayState();
}

class _BedtimeOverlayState extends State<BedtimeOverlay> {
  AudioPlayer? _audioPlayer;
  String? _currentPlayingNoise;
  bool _isPlayerPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _updateAudioPlayback(bool isBedtime, bool playNoises, String noiseType) async {
    if (!isBedtime || !playNoises) {
      if (_isPlayerPlaying) {
        await _audioPlayer?.pause();
        _isPlayerPlaying = false;
      }
      return;
    }

    if (_currentPlayingNoise != noiseType || !_isPlayerPlaying) {
      _currentPlayingNoise = noiseType;
      try {
        final assetPath = 'assets/audio/$noiseType.wav';
        await _audioPlayer?.setAsset(assetPath);
        await _audioPlayer?.setLoopMode(LoopMode.one);
        await _audioPlayer?.play();
        _isPlayerPlaying = true;
      } catch (e) {
        debugPrint('⚠️ Calm Mode: Error playing audio asset: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageProvider>();
    final settings = context.watch<SettingsProvider>();

    // Safely update audio playback post-render frame to prevent state-change-during-build errors.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateAudioPlayback(
          usage.isBedtime,
          settings.playSoothingNoises,
          settings.defaultBedtimeNoise,
        );
      }
    });

    return Material(
      color: Theme.of(
        context,
      ).scaffoldBackgroundColor, // Fundamental opaque background for the stack
      child: Stack(
        children: [
          // Standard app content
          AnimatedOpacity(
            opacity: usage.isBedtime ? 0.3 : 1.0,
            duration: const Duration(seconds: 2),
            child: IgnorePointer(ignoring: usage.isBedtime, child: widget.child),
          ),

          // Bedtime Screen
          if (usage.isBedtime) _buildBedtimeContent(context, usage, settings),
        ],
      ),
    );
  }

  Widget _buildBedtimeContent(
    BuildContext context,
    UsageProvider usage,
    SettingsProvider settings,
  ) {
    final loc = AppLocalizations.of(context);
    final calmMode = settings.bedtimeCalmModeEnabled;

    final content = SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAnimatedMoon(),
          const SizedBox(height: 24),
          Text(
            loc.translate('bedtime_title'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              loc.translate('bedtime_msg'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          const SizedBox(height: 36),

          // Soothing sound controls
          _buildSoundSelectorTray(context, settings),

          const SizedBox(height: 48),
          TactileButton(
            semanticLabel: loc.translate('parental_gate_title'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ParentalGate(
                    destination: _ExtraTimeDialog(usage: usage),
                  ),
                ),
              );
            },
            child: TactileCard(
              color: Colors.white.withValues(alpha: 0.15),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Icon(Icons.vpn_key_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF101026), // Ultra deep bedtime navy
            Color(0xFF2A0D3A), // Serene dark violet
          ],
        ),
      ),
      child: calmMode ? FallingStarsBackground(child: content) : content,
    );
  }

  Widget _buildSoundSelectorTray(BuildContext context, SettingsProvider settings) {
    final loc = AppLocalizations.of(context);
    final isPlaying = settings.playSoothingNoises;
    final currentNoise = settings.defaultBedtimeNoise;

    final soundItems = [
      {'id': 'lullaby', 'icon': Icons.auto_awesome_rounded, 'label': loc.translate('lullaby')},
      {'id': 'rain', 'icon': Icons.cloud_queue_rounded, 'label': loc.translate('rain')},
      {'id': 'ocean', 'icon': Icons.waves_rounded, 'label': loc.translate('ocean')},
      {'id': 'white_noise', 'icon': Icons.air_rounded, 'label': loc.translate('white_noise')},
    ];

    return GlassContainer(
      blur: 16.0,
      opacity: 0.55,
      borderRadius: BorderRadius.circular(40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause toggle
            TactileButton(
              semanticLabel: isPlaying ? 'Pause' : 'Play',
              onTap: () {
                settings.setPlaySoothingNoises(!isPlaying);
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying 
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.12),
                  boxShadow: isPlaying ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ] : null,
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),

            // Subtle vertical separator line (No solid border policy)
            Container(
              height: 32,
              width: 1,
              color: Colors.white.withValues(alpha: 0.15),
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),

            // Ambient sound selector icons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: soundItems.map((item) {
                final itemId = item['id'] as String;
                final isSelected = currentNoise == itemId;
                final icon = item['icon'] as IconData;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TactileButton(
                    semanticLabel: item['label'] as String,
                    onTap: () {
                      if (isSelected) {
                        settings.setPlaySoothingNoises(!isPlaying);
                      } else {
                        settings.setDefaultBedtimeNoise(itemId);
                        if (!isPlaying) {
                          settings.setPlaySoothingNoises(true);
                        }
                      }
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected 
                            ? Colors.white.withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.06),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 1,
                          )
                        ] : null,
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? Colors.white : Colors.white60,
                        size: 22,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedMoon() {
    return const AnimatedBedtimeMoon();
  }
}

class _ExtraTimeDialog extends StatelessWidget {
  final UsageProvider usage;
  const _ExtraTimeDialog({required this.usage});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(loc.translate('add_playtime'))),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              loc.translate('grant_extra_time'),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeButton(context, 5, loc),
                const SizedBox(width: 16),
                _buildTimeButton(context, 15, loc),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(
    BuildContext context,
    int mins,
    AppLocalizations loc,
  ) {
    return TactileButton(
      onTap: () {
        usage.grantExtraTime(mins);
        Navigator.pop(context);
      },
      child: TactileCard(
        color: Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Text(
            loc.translate('plus_mins', args: {'min': mins.toString()}),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
