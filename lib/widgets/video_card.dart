import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/tactile_widgets.dart';
import '../core/theme.dart';
import '../core/app_localizations.dart';
import '../providers/channel_provider.dart';
import '../services/youtube_service.dart';
import '../screens/watch_screen.dart';

class VideoCard extends StatelessWidget {
  final YoutubeVideo video;

  const VideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isNew = DateTime.now().difference(video.publishedAt).inDays < 7;
    final channelProvider = Provider.of<ChannelProvider>(
      context,
      listen: false,
    );

    final channel = channelProvider.channels.firstWhere(
      (c) => c.id == video.channelId,
      orElse: () => YoutubeChannel(id: '', name: 'Unknown', thumbnailUrl: ''),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: TactileButton(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WatchScreen(
                videoId: video.id,
                videoTitle: video.title, // Added title
                thumbnailUrl: video.thumbnailUrl,
                channelName: channel.name,
                channelThumbnailUrl: channel.thumbnailUrl,
              ),
            ),
          );
        },
        child: TactileCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),
                  ),
                  if (isNew)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: DadyTubeTheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          loc.translate('new_upload') ?? 'New',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      channel.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
      ),
    );
  }
}
