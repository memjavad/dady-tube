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

import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../core/app_localizations.dart';
import '../widgets/video_card.dart';

import '../services/video_cache_service.dart';
import 'offline_videos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
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


  Widget _buildSearchPlaceholder(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Center(child: Text(loc.translate('search_hint')));
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
