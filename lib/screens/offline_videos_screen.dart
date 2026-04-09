import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../providers/channel_provider.dart';
import '../core/app_localizations.dart';
import '../widgets/video_card.dart';
import '../widgets/particle_background.dart';
import '../core/theme.dart';

class OfflineVideosScreen extends StatefulWidget {
  const OfflineVideosScreen({super.key});

  @override
  State<OfflineVideosScreen> createState() => _OfflineVideosScreenState();
}

class _OfflineVideosScreenState extends State<OfflineVideosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh(context);
    });
  }

  Future<void> _refresh(BuildContext context) async {
    final channelProvider = context.read<ChannelProvider>();
    final downloadProvider = context.read<DownloadProvider>();
    await channelProvider.updateOfflineVideos(downloadProvider);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final channelProvider = context.watch<ChannelProvider>();
    final videos = channelProvider.offlineReadyVideos;

    return ParticleBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          onRefresh: () => _refresh(context),
          color: DadyTubeTheme.primary,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                floating: true,
                pinned: true,
                expandedHeight: 120.0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                  title: Text(
                    loc.translate('offline'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  centerTitle: false,
                ),
              ),
              if (videos.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(context, loc),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return VideoCard(video: videos[index]);
                      },
                      childCount: videos.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.card_travel_rounded,
              size: 80,
              color: DadyTubeTheme.primaryContainer,
            ),
            const SizedBox(height: 24),
            Text(
              loc.translate('empty_bag'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
