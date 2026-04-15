import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../providers/usage_provider.dart';
import '../providers/download_provider.dart';
import '../core/tactile_widgets.dart';
import '../core/theme.dart';
import '../services/youtube_service.dart';
import '../services/video_cache_service.dart';
import '../services/database_service.dart';
import '../core/app_localizations.dart';
import 'dart:io';
import '../providers/settings_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.translate('settings')),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: DadyTubeTheme.primary,
            labelColor: DadyTubeTheme.primary,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            isScrollable: true,
            tabs: [
              Tab(text: loc.translate('experience')),
              Tab(text: loc.translate('safety')),
              Tab(text: loc.translate('channels')),
              Tab(text: loc.translate('statistics')),
              Tab(text: loc.translate('guide')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ExperienceTab(),
            _SafetyTab(),
            _ChannelsTab(),
            _StatisticsTab(),
            _GuideTab(),
          ],
        ),
      ),
    );
  }
}

class _ExperienceTab extends StatelessWidget {
  const _ExperienceTab();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final settings = context.watch<SettingsProvider>();
    final usage = context.watch<UsageProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            loc.translate('language'),
            Icons.language_rounded,
          ),
          const SizedBox(height: 16),
          _buildLanguageSelector(context, settings, loc),
          const SizedBox(height: 32),
          _buildSectionHeader(
            context,
            loc.translate('video_experience'),
            Icons.video_settings_rounded,
          ),
          const SizedBox(height: 16),
          _buildQualitySelector(context, settings, loc),
          const SizedBox(height: 16),
          _buildSettingToggle(
            context,
            loc.translate('full_screen_playback'),
            settings.fullScreenByDefault,
            (val) => settings.setFullScreenByDefault(val),
          ),
          const SizedBox(height: 16),
          _buildSettingToggle(
            context,
            loc.translate('show_suggestions'),
            settings.showSuggestions,
            (val) => settings.setShowSuggestions(val),
          ),
          const SizedBox(height: 16),
          _buildSettingToggle(
            context,
            loc.translate('eye_protection'),
            settings.eyeProtectionEnabled,
            (val) => settings.setEyeProtection(val),
          ),
          const SizedBox(height: 16),
          _buildTurboModeToggle(context, settings, loc),
          const SizedBox(height: 32),
          _buildSectionHeader(
            context,
            loc.translate('theme'),
            Icons.palette_rounded,
          ),
          const SizedBox(height: 16),
          _buildThemeSelector(context, settings, loc),
          const SizedBox(height: 32),
          _buildSectionHeader(
            context,
            loc.translate('bedtime_title'),
            Icons.nightlight_round,
          ),
          const SizedBox(height: 16),
          _buildUsageTimerCard(context, usage, loc),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations loc,
  ) {
    return TactileCard(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          _buildLangOption(
            context,
            settings,
            const Locale('ar', 'IQ'),
            loc.translate('arabic'),
          ),
          const SizedBox(width: 8),
          _buildLangOption(
            context,
            settings,
            const Locale('en', 'US'),
            loc.translate('english'),
          ),
        ],
      ),
    );
  }

  Widget _buildLangOption(
    BuildContext context,
    SettingsProvider settings,
    Locale locale,
    String label,
  ) {
    final isSelected = settings.locale.languageCode == locale.languageCode;
    return Expanded(
      child: TactileButton(
        onTap: () => settings.setLocale(locale),
        child: TactileCard(
          color: isSelected ? DadyTubeTheme.primary : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQualitySelector(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations loc,
  ) {
    return TactileCard(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: VideoQuality.values.map((quality) {
          final isSelected = settings.videoQuality == quality;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TactileButton(
                onTap: () => settings.setVideoQuality(quality),
                child: TactileCard(
                  color: isSelected
                      ? DadyTubeTheme.primary
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      quality.name.toUpperCase().replaceAll('P', ''),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildThemeSelector(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations loc,
  ) {
    return TactileCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              _buildThemeOption(
                context,
                settings,
                AppThemeLevel.blush,
                loc.translate('theme_blush'),
              ),
              const SizedBox(width: 8),
              _buildThemeOption(
                context,
                settings,
                AppThemeLevel.sunset,
                loc.translate('theme_sunset'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildThemeOption(
                context,
                settings,
                AppThemeLevel.midnight,
                loc.translate('theme_midnight'),
              ),
              const SizedBox(width: 8),
              _buildThemeOption(
                context,
                settings,
                AppThemeLevel.deepSpace,
                loc.translate('theme_deep_space'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    SettingsProvider settings,
    AppThemeLevel level,
    String label,
  ) {
    final isSelected = settings.themeLevel == level;
    final themeData = DadyTubeTheme.getTheme(level);
    return Expanded(
      child: TactileButton(
        onTap: () => settings.setThemeLevel(level),
        child: TactileCard(
          color: isSelected
              ? themeData.colorScheme.primary
              : (themeData.brightness == Brightness.dark
                    ? Colors.white10
                    : Colors.black.withOpacity(0.05)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsageTimerCard(
    BuildContext context,
    UsageProvider usage,
    AppLocalizations loc,
  ) {
    return TactileCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.translate('daily_limit'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${usage.dailyLimitMinutes} ${loc.translate('minutes')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: DadyTubeTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Slider(
            value: usage.dailyLimitMinutes.toDouble(),
            min: 5,
            max: 200,
            divisions: 39, // (200 - 5) / 5 = 39 divisions for 5-min increments
            activeColor: DadyTubeTheme.primary,
            onChanged: (val) => usage.setDailyLimit(val.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildTurboModeToggle(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations loc,
  ) {
    return TactileCard(
      color: settings.turboModeEnabled
          ? Colors.orangeAccent.withOpacity(0.1)
          : null,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(
            Icons.rocket_launch_rounded,
            color: Colors.orangeAccent,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Turbo Mode", // Keeping it simple or we can add to loc later
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  "Hyper-speed for slow internet",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: settings.turboModeEnabled,
            onChanged: (val) => settings.setTurboMode(val),
            activeColor: Colors.orangeAccent,
          ),
        ],
      ),
    );
  }
}

class _SafetyTab extends StatelessWidget {
  const _SafetyTab();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final settings = context.watch<SettingsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            loc.translate('safety_settings'),
            Icons.security_rounded,
          ),
          const SizedBox(height: 16),
          _buildBlockedKeywordsSection(context, loc, settings),
          const SizedBox(height: 32),
          _buildSectionHeader(
            context,
            loc.translate('smart_features'),
            Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 16),
          _buildAutoCacheToggle(context, loc, settings),
          const SizedBox(height: 16),
          _buildSettingToggle(
            context,
            loc.translate('rest_reminders'),
            settings.restRemindersEnabled,
            (val) => settings.setRestReminders(val),
          ),
          const SizedBox(height: 16),
          _buildSettingToggle(
            context,
            loc.translate('distance_protection'),
            settings.distanceProtectionEnabled,
            (val) => settings.setDistanceProtection(val),
          ),
          const SizedBox(height: 16),
          _buildSettingToggle(
            context,
            loc.translate('posture_protection'),
            settings.postureProtectionEnabled,
            (val) => settings.setPostureProtection(val),
          ),
          const SizedBox(height: 16),
          _buildSettingToggle(
            context,
            loc.translate('safe_volume_mode'),
            settings.safeVolumeEnabled,
            (val) => settings.setSafeVolumeEnabled(val),
          ),
          if (settings.safeVolumeEnabled) ...[
            const SizedBox(height: 16),
            _buildVolumeSlider(context, settings, loc),
          ],
        ],
      ),
    );
  }

  Widget _buildVolumeSlider(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations loc,
  ) {
    return TactileCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.translate('max_volume_level'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '${(settings.maxVolumeLevel * 100).toInt()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: DadyTubeTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: settings.maxVolumeLevel,
            min: 0.1,
            max: 1.0,
            activeColor: DadyTubeTheme.primary,
            onChanged: (val) => settings.setMaxVolumeLevel(val),
          ),
          Text(
            loc.translate('safe_volume_desc'),
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoCacheToggle(
    BuildContext context,
    AppLocalizations loc,
    SettingsProvider settings,
  ) {
    return TactileCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.translate('auto_cache_title'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.translate('auto_cache_desc'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch.adaptive(
            value: settings.autoCacheEnabled,
            onChanged: (val) => settings.setAutoCacheEnabled(val),
            activeColor: DadyTubeTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedKeywordsSection(
    BuildContext context,
    AppLocalizations loc,
    SettingsProvider settings,
  ) {
    final controller = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TactileCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: loc.translate('search_hint').replaceAll('!', ''),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TactileButton(
                semanticLabel: loc.translate('add_keyword') ?? 'Add keyword',
                onTap: () {
                  if (controller.text.isNotEmpty) {
                    settings.addBlockedKeyword(controller.text);
                    controller.clear();
                  }
                },
                child: const TactileCard(
                  color: DadyTubeTheme.primary,
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.add_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: settings.blockedKeywords.map((keyword) {
            return Chip(
              label: Text(keyword),
              onDeleted: () => settings.removeBlockedKeyword(keyword),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerLow,
              deleteIcon: const Icon(Icons.cancel_rounded, size: 18),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ChannelsTab extends StatelessWidget {
  const _ChannelsTab();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final provider = context.watch<ChannelProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            loc.translate('add_channel'),
            Icons.add_to_queue_rounded,
          ),
          const SizedBox(height: 16),
          _buildAddChannelCard(context, provider, loc),
          const SizedBox(height: 32),
          _buildSectionHeader(
            context,
            loc.translate('your_channels'),
            Icons.list_alt_rounded,
          ),
          const SizedBox(height: 16),
          _buildChannelList(context, provider, loc),
        ],
      ),
    );
  }

  Widget _buildAddChannelCard(
    BuildContext context,
    ChannelProvider provider,
    AppLocalizations loc,
  ) {
    final controller = TextEditingController();
    return TactileCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'youtube.com/@...',
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TactileButton(
            semanticLabel: loc.translate('add_channel'),
            onTap: () async {
              if (controller.text.isNotEmpty) {
                final channel = await YoutubeService.getChannelInfo(
                  controller.text,
                );
                if (channel != null) {
                  provider.addChannel(channel);
                  controller.clear();
                }
              }
            },
            child: const TactileCard(
              color: DadyTubeTheme.primary,
              padding: EdgeInsets.all(12),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelList(
    BuildContext context,
    ChannelProvider provider,
    AppLocalizations loc,
  ) {
    return Column(
      children: provider.channels.map((channel) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TactileCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: channel.localThumbnailPath != null && File(channel.localThumbnailPath!).existsSync()
                      ? FileImage(File(channel.localThumbnailPath!))
                      : (channel.thumbnailUrl.isNotEmpty ? CachedNetworkImageProvider(channel.thumbnailUrl) : null) as ImageProvider?,
                  child: channel.thumbnailUrl.isEmpty && channel.localThumbnailPath == null
                      ? const Icon(Icons.person_rounded)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    channel.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                  tooltip: loc.translate('remove_channel'),
                  onPressed: () => provider.removeChannel(channel.id),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

Widget _buildSettingToggle(
  BuildContext context,
  String title,
  bool value,
  Function(bool) onChanged,
) {
  return TactileCard(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: DadyTubeTheme.primary,
        ),
      ],
    ),
  );
}

Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
  return Row(
    children: [
      Icon(icon, color: DadyTubeTheme.primary, size: 24),
      const SizedBox(width: 12),
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ],
  );
}

class _GuideTab extends StatelessWidget {
  const _GuideTab();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildGuideCard(
            context,
            loc.translate('guide_magic_stars_title'),
            loc.translate('guide_magic_stars_desc'),
            Icons.auto_awesome_rounded,
            Colors.amber,
          ),
          const SizedBox(height: 16),
          _buildGuideCard(
            context,
            loc.translate('guide_distance_title'),
            loc.translate('guide_distance_desc'),
            Icons.straighten_rounded,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildGuideCard(
            context,
            loc.translate('guide_eye_yoga_title'),
            loc.translate('guide_eye_yoga_desc'),
            Icons.visibility_rounded,
            Colors.green,
          ),
          const SizedBox(height: 16),
          _buildGuideCard(
            context,
            loc.translate('guide_calm_mode_title'),
            loc.translate('guide_calm_mode_desc'),
            Icons.nightlight_round,
            Colors.indigo,
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard(
    BuildContext context,
    String title,
    String desc,
    IconData icon,
    Color accentColor,
  ) {
    return TactileCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            desc,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsTab extends StatefulWidget {
  @override
  State<_StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<_StatisticsTab> {
  Map<String, dynamic>? _cacheStats;
  int _channelCount = 0;
  int _videoCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await VideoCacheService().getCacheStatistics();
    final chCount = await DatabaseService.instance.getTotalChannelCount();
    final vidCount = await DatabaseService.instance.getTotalVideoCount();
    if (mounted) {
      setState(() {
        _cacheStats = stats;
        _channelCount = chCount;
        _videoCount = vidCount;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final downloadProvider = context.watch<DownloadProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final int downloadedCount = downloadProvider.downloadedVideos.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTotalSummaryCard(context),
          const SizedBox(height: 24),
          if (_isSyncing)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TactileCard(
                color: DadyTubeTheme.primary.withOpacity(0.1),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Refreshing Worlds & Cache...',
                      style: TextStyle(
                        color: DadyTubeTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _buildSectionHeader(
            context,
            loc.translate('storage_usage'),
            Icons.storage_rounded,
          ),
          const SizedBox(height: 16),
          if (_cacheStats == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildStatCard(
              context,
              loc.translate('cached_videos'),
              '${_cacheStats!['mp4Count']} videos, ${_cacheStats!['previewCount']} previews\n${_formatBytes(_cacheStats!['totalBytes'])}',
              Icons.video_library_rounded,
              Colors.purple,
              onClear: () async {
                await VideoCacheService().clearAllCache();
                _loadStats();
              },
              onAction: () async {
                setState(() => _isSyncing = true);
                await channelProvider.forceSyncFull();
                await _loadStats();
                setState(() => _isSyncing = false);
              },
              actionLabel: 'Pre-cache',
              actionIcon: Icons.auto_awesome_rounded,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              loc.translate('instant_play_links'),
              '${_cacheStats!['urlCount']} cached URLs',
              Icons.link_rounded,
              Colors.teal,
              onClear: () async {
                final prefs = await SharedPreferences.getInstance();
                final keys = prefs.getKeys().where(
                  (k) => k.startsWith('stream_link_'),
                );
                for (var key in keys) {
                  await prefs.remove(key);
                }
                _loadStats();
              },
              onAction: () async {
                setState(() => _isSyncing = true);
                await channelProvider.loadAllVideos();
                await _loadStats();
                setState(() => _isSyncing = false);
              },
              actionLabel: 'Refresh',
            ),
          ],
          const SizedBox(height: 32),
          _buildSectionHeader(
            context,
            loc.translate('manual_downloads'),
            Icons.card_travel_rounded,
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            context,
            loc.translate('manual_downloads'),
            '$downloadedCount videos saved offline',
            Icons.offline_pin_rounded,
            Colors.green,
            onClear: () async {
              await downloadProvider.clearAllDownloads();
              _loadStats();
            },
            onAction: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            actionLabel: 'Home',
            actionIcon: Icons.home_rounded,
          ),
          const SizedBox(height: 32),
          _buildSectionHeader(
            context,
            loc.translate('metadata_stored'),
            Icons.my_library_books_rounded,
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            context,
            loc.translate('metadata_stored'),
            '$_channelCount channels\n$_videoCount videos indexed',
            Icons.sd_storage_rounded,
            Colors.orange,
            onClear: () async {
              await DatabaseService.instance.clearAllVideos();
              _loadStats();
            },
            onAction: () async {
              setState(() => _isSyncing = true);
              await channelProvider.loadAllVideos();
              await _loadStats();
              setState(() => _isSyncing = false);
            },
            actionLabel: 'Sync All',
            actionIcon: Icons.cloud_download_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onClear,
    VoidCallback? onAction,
    IconData? actionIcon,
    String? actionLabel,
  }) {
    return TactileCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onClear != null || onAction != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onClear != null)
                  _buildSmallActionBtn(
                    context,
                    Icons.delete_outline_rounded,
                    'Clear',
                    Colors.redAccent,
                    onClear,
                  ),
                if (onClear != null && onAction != null)
                  const SizedBox(width: 8),
                if (onAction != null)
                  _buildSmallActionBtn(
                    context,
                    actionIcon ?? Icons.refresh_rounded,
                    actionLabel ?? 'Sync',
                    DadyTubeTheme.primary,
                    onAction,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalSummaryCard(BuildContext context) {
    if (_cacheStats == null) return const SizedBox.shrink();

    return TactileCard(
      color: DadyTubeTheme.primary,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your DadyTube Bag',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatBytes(_cacheStats!['totalBytes'])} used locally',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActionBtn(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return TactileButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
