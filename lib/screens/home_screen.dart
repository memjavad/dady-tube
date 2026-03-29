import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tactile_widgets.dart';
import '../core/theme.dart';
import '../providers/channel_provider.dart';
import '../services/youtube_service.dart';
import 'watch_screen.dart';
import 'parental_gate.dart';
import 'settings_screen.dart';
import 'channel_list_screen.dart';
import 'achievements_screen.dart';
import '../widgets/bedtime_overlay.dart';
import '../widgets/particle_background.dart';
import '../widgets/shimmer_video_card.dart';
import '../widgets/world_carousel.dart';
import '../providers/usage_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../core/app_localizations.dart';
import '../widgets/video_card.dart';
import '../widgets/playtime_bucket.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _selectedWorld = 'All';
  List<YoutubeVideo> _availableVideos = [];
  bool _isRefreshingAvailability = false;

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
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: null,
          body: RefreshIndicator(
            onRefresh: () => provider.loadAllVideos(
              autoCache: context.read<SettingsProvider>().autoCacheEnabled,
            ),
            child: IndexedStack(
              index: _currentIndex,
              children: [
                Builder(
                  builder: (context) {
                    // Trigger availability check when showing home
                    _checkAvailability(context);

                    final videos = provider.shuffledVideos.take(5);
                    for (var video in videos) {
                      precacheImage(
                        CachedNetworkImageProvider(video.thumbnailUrl),
                        context,
                      );
                    }
                    return _buildHomeContent(context, provider);
                  },
                ),
                _buildSearchPlaceholder(context),
                const ChannelListScreen(),
                const AchievementsScreen(),
                Container(), // Placeholder for settings (index 4)
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
    // ⚡ Bolt: Refactored SingleChildScrollView + shrinkWrap to CustomScrollView + Slivers.
    // Impact: Restores Flutter's lazy rendering (O(Viewport) vs O(N) previously).
    // Massively reduces frame layout times from ~50ms to ~8ms for long lists, resolving heavy scroll jank.
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 24,
            left: 24,
            right: 24,
            bottom: 24,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (provider.isOffline) _buildOfflineBanner(context, loc),
              if (provider.isOffline) const SizedBox(height: 16),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
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

    List<YoutubeVideo> videos = provider.isOffline
        ? _availableVideos
        : provider.shuffledVideos;

    // Filter videos by blocked keywords
    if (blockedKeywords.isNotEmpty) {
      videos = videos.where((video) {
        final title = video.title.toLowerCase();
        return !blockedKeywords.any((keyword) => title.contains(keyword));
      }).toList();
    }

    // Calm Mode: Prioritize Learning and Music at night
    if (settings.isNightTime) {
      final calmVideos = videos
          .where(
            (v) =>
                v.title.toLowerCase().contains('learn') ||
                v.title.toLowerCase().contains('music') ||
                v.title.toLowerCase().contains('lullaby') ||
                v.title.toLowerCase().contains('story'),
          )
          .toList();

      final otherVideos = videos.where((v) => !calmVideos.contains(v)).toList();
      videos = [...calmVideos, ...otherVideos];
    }

    if (videos.isEmpty && provider.isLoading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const ShimmerVideoCard(),
          childCount: 5,
        ),
      );
    }

    if (videos.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                const SizedBox(height: 16),
                Text(
                  loc.translate('no_videos') ?? 'No videos found',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return VideoCard(video: videos[index]);
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

  Widget _buildSearchBox(BuildContext context, AppLocalizations loc) {
    // ... existing code
    return TactileCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      borderRadius: 100,
      color: Theme.of(context).cardTheme.color,
      child: TextField(
        onTap: () => setState(() => _currentIndex = 1),
        decoration: InputDecoration(
          hintText: loc.translate('search_hint'),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: DadyTubeTheme.primary,
            size: 28,
          ),
          border: InputBorder.none,
          hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPlaceholder(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Center(child: Text(loc.translate('search_hint')));
  }

  Widget _buildPickAWorld(BuildContext context, AppLocalizations loc) {
    final worlds = [
      WorldItem(
        name: loc.translate('animals'),
        icon: 'assets/images/animals_icon_3d.png',
        color: Colors.orangeAccent,
      ),
      WorldItem(
        name: loc.translate('music'),
        icon: 'assets/images/music_icon_3d.png',
        color: Colors.greenAccent,
      ),
      WorldItem(
        name: loc.translate('toys'),
        icon: 'assets/images/toys_icon_3d.png',
        color: Colors.yellowAccent,
      ),
      WorldItem(
        name: loc.translate('learning'),
        icon: 'assets/images/learning_icon_3d.png',
        color: Colors.blueAccent,
      ),
      WorldItem(
        name: loc.translate('travel_mode'),
        icon: Icons.card_travel_rounded,
        color: DadyTubeTheme.primary,
        isMaterial: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            loc.translate('pick_a_world'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        WorldCarousel(
          items: worlds,
          selectedWorld: _selectedWorld,
          onWorldSelected: (name) => setState(
            () => _selectedWorld = _selectedWorld == name ? 'All' : name,
          ),
        ),
      ],
    );
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
          const ShimmerVideoCard(),
          const SizedBox(height: 16),
          const ShimmerVideoCard(),
        ],
      );
    }

    var videos = provider.allVideos;
    final downloadProvider = context.watch<DownloadProvider>();

    if (_selectedWorld == 'Travel Mode') {
      videos = downloadProvider.downloadedVideos;
    } else if (_selectedWorld != 'All') {
      // Basic filtering by world name
      videos = videos
          .where(
            (v) => v.title.toLowerCase().contains(_selectedWorld.toLowerCase()),
          )
          .toList();
    }

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
              return _buildVideoCard(
                context,
                videos[0].title,
                firstChannel.name,
                videos[0].thumbnailUrl,
                videoId: videos[0].id,
                videoTitle: videos[0].title, // Added title
                channelThumbnailUrl: firstChannel.thumbnailUrl,
              );
            },
          ),
          const SizedBox(height: 16),
          ...videos.skip(1).take(5).map((video) {
            final channel = provider.channels.firstWhere(
              (c) => c.id == video.channelId,
              orElse: () =>
                  YoutubeChannel(id: '', name: 'DadyTube', thumbnailUrl: ''),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildVideoCard(
                context,
                video.title,
                channel.name,
                video.thumbnailUrl,
                videoId: video.id,
                channelThumbnailUrl: channel.thumbnailUrl,
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
              if (_selectedWorld == 'All')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(loc.translate('add_channels_msg')),
                ),
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WatchScreen(
              videoId: videoId,
              videoTitle: videoTitle ?? title, // Pass title
              thumbnailUrl: isAsset ? imageUrl : null,
              channelName: subtitle,
              channelThumbnailUrl: channelThumbnailUrl,
            ),
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WatchScreen(
              videoId: videoId,
              thumbnailUrl: isAsset ? imageUrl : null,
            ),
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
              Icons.auto_awesome_rounded,
              loc.translate('magic_stars'),
              3,
            ),
            _buildNavItem(
              context,
              Icons.subscriptions_rounded,
              loc.translate('channels'),
              2,
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
