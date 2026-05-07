import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tactile_widgets.dart';
import '../providers/channel_provider.dart';
import '../services/youtube_service.dart';
import 'parental_gate.dart';
import 'settings_screen.dart';
import 'channel_list_screen.dart';
import 'achievements_screen.dart';
import '../widgets/bedtime_overlay.dart';
import '../widgets/particle_background.dart';
import '../widgets/shimmer_video_card.dart';
import '../providers/usage_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../core/app_localizations.dart';
import '../widgets/video_card.dart';

import '../services/video_cache_service.dart';
import 'offline_videos_screen.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme.dart';
import 'watch_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<YoutubeVideo> _availableVideos = [];
  bool _isRefreshingAvailability = false;
  String _selectedWorld = 'All';

  @override
  void initState() {
    super.initState();
    // Start background sync after 15 seconds of idle time to avoid startup lag
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        context.read<ChannelProvider>().triggerBackgroundSync();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChannelProvider>();

    return BedtimeOverlay(
      child: ParticleBackground(
        overrideColor: null,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: null,
          body: RefreshIndicator(
            onRefresh: () => provider.loadAllVideos(),
            child: IndexedStack(
              index: _currentIndex,
              children: [
                Builder(
                  builder: (context) {
                    // Trigger availability check when showing home
                    _checkAvailability(context);
                    return _buildHomeContent(context, provider);
                  },
                ),
                _buildSearchPlaceholder(context),
                const ChannelListScreen(),
                const AchievementsScreen(),
                Container(), // Placeholder for settings (index 4)
                const OfflineVideosScreen(), // Index 5
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(context),
        ),
      ),
    );
  }

  Future<void> _checkAvailability(BuildContext context) async {
    final provider = context.read<ChannelProvider>();
    if (!provider.isOffline) return;
    if (_isRefreshingAvailability) return;

    setState(() => _isRefreshingAvailability = true);
    final vids = await provider.getAvailableVideos(
      context.read<DownloadProvider>(),
    );
    if (mounted) {
      setState(() {
        _availableVideos = vids;
        _isRefreshingAvailability = false;
      });
    }
  }

  Widget _buildHomeContent(BuildContext context, ChannelProvider provider) {
    final loc = AppLocalizations.of(context);
    // ⚡ Bolt: Using CustomScrollView instead of SingleChildScrollView to avoid ListView shrinkWrap bottleneck.
    // This allows Slivers to render lazily, significantly reducing memory and CPU usage on long lists.
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (provider.isOffline)
          SliverPadding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 24,
              right: 24,
              bottom: 16, // Instead of SizedBox(height: 16)
            ),
            sliver: SliverToBoxAdapter(
              child: _buildOfflineBanner(context, loc),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.only(
            top: provider.isOffline
                ? 0
                : MediaQuery.of(context).padding.top + 24,
            left: 24,
            right: 24,
            bottom: 24,
          ),
          sliver: _buildBigImmersiveList(context, provider, loc),
        ),
      ],
    );
  }

  Widget _buildOfflineBanner(BuildContext context, AppLocalizations loc) {
    return TactileCard(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.translate('offline_mode_active'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  loc.translate('offline_mode_desc'),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigImmersiveList(
    BuildContext context,
    ChannelProvider provider,
    AppLocalizations loc,
  ) {
    final provider = context.watch<ChannelProvider>();
    final settings = context.watch<SettingsProvider>();
    final blockedKeywords = settings.blockedKeywords;

    final videos = provider.getFilteredBigList(
      isOffline: provider.isOffline,
      availableVideos: _availableVideos,
      blockedKeywords: blockedKeywords,
      isNightTime: settings.isNightTime,
    );

    if (videos.isEmpty && provider.isLoading) {
      // ⚡ Bolt: Using SliverList instead of ListView with shrinkWrap: true.
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const ShimmerVideoCard(),
          childCount: 5,
        ),
      );
    }

    // ⚡ Bolt: Using SliverList instead of ListView with shrinkWrap: true.
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return StaggeredEntryCard(
          uniqueId: videos[index].id,
          index: index,
          child: VideoCard(video: videos[index]),
        );
      }, childCount: videos.length),
    );
  }

  final List<Map<String, String>> _magicBubbles = [
    {'emoji': '🦖', 'query': 'Dinosaurs'},
    {'emoji': '🚂', 'query': 'Trains'},
    {'emoji': '🎶', 'query': 'Nursery Rhymes'},
    {'emoji': '🎨', 'query': 'Coloring'},
    {'emoji': '🦄', 'query': 'Magic'},
    {'emoji': '🐱', 'query': 'Cats'},
    {'emoji': '🚀', 'query': 'Space'},
  ];

  Widget _buildMagicBubbles(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _magicBubbles.length,
        itemBuilder: (context, index) {
          final bubble = _magicBubbles[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TactileButton(
              onTap: () {
                // In a real app, this would trigger search
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Searching for ${bubble['query']}...'),
                  ),
                );
              },
              child: TactileCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                borderRadius: 25,
                color: Colors.white,
                child: Row(
                  children: [
                    Text(
                      bubble['emoji']!,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      bubble['query']!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchPlaceholder(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Center(child: Text(loc.translate('search_hint')));
  }

  Widget _buildPopularFeed(
    BuildContext context,
    ChannelProvider provider,
    AppLocalizations loc,
  ) {
    if (provider.isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerHeader(),
          const SizedBox(height: 24),
          const StaggeredEntryCard(index: 0, child: ShimmerVideoCard()),
          const SizedBox(height: 16),
          const StaggeredEntryCard(index: 1, child: ShimmerVideoCard()),
        ],
      );
    }

    final downloadProvider = context.watch<DownloadProvider>();
    final videos = provider.getFilteredPopularList(
      selectedWorld: _selectedWorld,
      downloadedVideos: downloadProvider.downloadedVideos,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedWorld == 'All'
                  ? loc.translate('popular_now')
                  : '${loc.translate('exploring')} $_selectedWorld',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (_selectedWorld != 'All')
              TactileButton(
                onTap: () => setState(() => _selectedWorld = 'All'),
                child: Text(
                  loc.translate('reset'),
                  style: const TextStyle(
                    color: DadyTubeTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (videos.isEmpty)
          _buildEmptyFeed(loc)
        else ...[
          Builder(
            builder: (context) {
              final firstChannel = provider.channels.firstWhere(
                (c) => c.id == videos[0].channelId,
                orElse: () =>
                    YoutubeChannel(id: '', name: 'DadyTube', thumbnailUrl: ''),
              );
              return StaggeredEntryCard(
                uniqueId: videos[0].id,
                index: 0,
                child: _buildVideoCard(
                  context,
                  videos[0].title,
                  firstChannel.name,
                  videos[0].thumbnailUrl,
                  videoId: videos[0].id,
                  videoTitle: videos[0].title,
                  channelThumbnailUrl: firstChannel.thumbnailUrl,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ...videos.skip(1).take(5).toList().asMap().entries.map((entry) {
            final index = entry.key + 1;
            final video = entry.value;
            final channel = provider.channels.firstWhere(
              (c) => c.id == video.channelId,
              orElse: () =>
                  YoutubeChannel(id: '', name: 'DadyTube', thumbnailUrl: ''),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: StaggeredEntryCard(
                uniqueId: video.id,
                index: index,
                child: _buildVideoCard(
                  context,
                  video.title,
                  channel.name,
                  video.thumbnailUrl,
                  videoId: video.id,
                  channelThumbnailUrl: channel.thumbnailUrl,
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildShimmerHeader() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerLow,
      highlightColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
      child: Container(
        height: 32,
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildEmptyFeed(AppLocalizations loc) {
    return TactileCard(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.toys_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              const SizedBox(height: 24),
              Text(
                _selectedWorld == 'Travel Mode'
                    ? loc.translate('empty_bag')
                    : loc.translate('no_videos'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              if (_selectedWorld == 'All') ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(loc.translate('add_channels_msg')),
                ),
                const SizedBox(height: 24),
                TactileButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ParentalGate(destination: SettingsScreen()),
                      ),
                    );
                  },
                  child: TactileCard(
                    color: DadyTubeTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loc.translate('settings'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(
    BuildContext context,
    String title,
    String subtitle,
    String imageUrl, {
    bool isAsset = false,
    String videoId = 'L_LUpnjyPso',
    String? videoTitle,
    String? channelThumbnailUrl,
  }) {
    return TactileButton(
      onTapDown: () {
        VideoCacheService().prefetchManifest(videoId);
      },
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 250),
            pageBuilder: (context, animation, secondaryAnimation) =>
                WatchScreen(
                  videoId: videoId,
                  videoTitle: videoTitle ?? title,
                  thumbnailUrl: isAsset ? imageUrl : null,
                  channelName: subtitle,
                  channelThumbnailUrl: channelThumbnailUrl,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        );
      },
      child: TactileCard(
        padding: EdgeInsets.zero,
        borderRadius: 32,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: isAsset
                  ? Image.asset(
                      imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : CachedNetworkImage(
                      imageUrl: YoutubeService.getOptimizedThumbnail(
                        imageUrl,
                        context.read<SettingsProvider>().turboModeEnabled,
                      ),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: DadyTubeTheme.surfaceContainerLow),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoListItem(
    BuildContext context,
    String title,
    String subtitle,
    String imageUrl, {
    bool isAsset = false,
    String videoId = 'L_LUpnjyPso',
  }) {
    return TactileButton(
      onTapDown: () {
        VideoCacheService().prefetchManifest(videoId);
      },
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 250),
            pageBuilder: (context, animation, secondaryAnimation) =>
                WatchScreen(
                  videoId: videoId,
                  thumbnailUrl: isAsset ? imageUrl : null,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        );
      },
      child: TactileCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 24,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: isAsset
                  ? Image.asset(
                      imageUrl,
                      height: 80,
                      width: 120,
                      fit: BoxFit.cover,
                    )
                  : CachedNetworkImage(
                      imageUrl: YoutubeService.getOptimizedThumbnail(
                        imageUrl,
                        context.read<SettingsProvider>().turboModeEnabled,
                      ),
                      height: 80,
                      width: 120,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: DadyTubeTheme.surfaceContainerLow),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return GlassContainer(
      blur: 16,
      opacity: 0.6,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              context,
              Icons.play_arrow_rounded,
              loc.translate('play'),
              0,
            ),
            _buildNavItem(
              context,
              Icons.download_done_rounded,
              loc.translate('offline'),
              5,
            ),
            _buildNavItem(
              context,
              Icons.subscriptions_rounded,
              loc.translate('channels'),
              2,
            ),
            _buildNavItem(
              context,
              Icons.auto_awesome_rounded,
              loc.translate('magic_stars'),
              3,
            ),
            _buildNavItem(
              context,
              Icons.person_rounded,
              loc.translate('settings'),
              4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
  ) {
    final isActive = _currentIndex == index;
    return TactileButton(
      onTap: () {
        if (index == 4) {
          // Push ParentalGate as a separate route for settings
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const ParentalGate(destination: SettingsScreen()),
            ),
          );
        } else {
          setState(() => _currentIndex = index);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingWidget extends StatefulWidget {
  final Widget child;
  const FloatingWidget({super.key, required this.child});

  @override
  State<FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<FloatingWidget>
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
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class StaggeredEntryCard extends StatefulWidget {
  final Widget child;
  final int index;
  final String? uniqueId;
  const StaggeredEntryCard({
    super.key,
    required this.child,
    required this.index,
    this.uniqueId,
  });

  @override
  State<StaggeredEntryCard> createState() => _StaggeredEntryCardState();
}

class _StaggeredEntryCardState extends State<StaggeredEntryCard> {
  static final Set<String> _animatedIds = {};
  bool _shouldAnimate = false;

  @override
  void initState() {
    super.initState();
    if (widget.uniqueId != null) {
      if (!_animatedIds.contains(widget.uniqueId)) {
        _animatedIds.add(widget.uniqueId!);
        _shouldAnimate = true;
      }
      // ⚡ Viewport Pre-warming: Instantly queue this video's stream URL when scrolled onto screen
      VideoCacheService().prefetchManifest(widget.uniqueId!);
    } else {
      // If no ID is provided, animate based on index for fallback UI Elements like shimmer
      _shouldAnimate = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldAnimate) {
      return widget.child;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(
        milliseconds: 400 + (widget.index * 100).clamp(0, 600),
      ),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: widget.child,
    );
  }
}
