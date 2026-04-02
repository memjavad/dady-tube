import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../providers/settings_provider.dart';
import '../services/youtube_service.dart';
import '../core/theme.dart';
import '../core/app_localizations.dart';
import '../widgets/video_card.dart';
import '../widgets/particle_background.dart';

class ChannelFeedScreen extends StatelessWidget {
  final YoutubeChannel channel;

  const ChannelFeedScreen({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final provider = context.watch<ChannelProvider>();
    final settings = context.watch<SettingsProvider>();
    final blockedKeywords = settings.blockedKeywords;

    List<YoutubeVideo> videos = provider.channelVideos[channel.id] ?? [];

    // Filter videos by blocked keywords
    if (blockedKeywords.isNotEmpty) {
      videos = videos.where((video) {
        final title = video.title.toLowerCase();
        return !blockedKeywords.any((keyword) => title.contains(keyword));
      }).toList();
    }

    // Sort by latest first
    videos.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return ParticleBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DadyTubeTheme.primary),
            onPressed: () => Navigator.pop(context),
            tooltip: loc.translate('back'),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: channel.thumbnailUrl.isNotEmpty ? NetworkImage(channel.thumbnailUrl) : null,
                backgroundColor: DadyTubeTheme.primaryContainer,
                child: channel.thumbnailUrl.isEmpty ? const Icon(Icons.tv_rounded, size: 16, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  channel.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        body: videos.isEmpty
            ? _buildEmptyState(context, loc)
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  return VideoCard(video: videos[index]);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_library_rounded, size: 80, color: DadyTubeTheme.primaryContainer),
          const SizedBox(height: 24),
          Text(
            loc.translate('no_videos'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}
