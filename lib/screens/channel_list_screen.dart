import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../core/tactile_widgets.dart';
import '../core/theme.dart';
import '../core/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../services/youtube_service.dart';
import 'watch_screen.dart';

import 'channel_feed_screen.dart';

class ChannelListScreen extends StatelessWidget {
  const ChannelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final provider = context.watch<ChannelProvider>();
    final channels = provider.channels;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          loc.translate('your_channels'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: DadyTubeTheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: channels.isEmpty
          ? _buildEmptyState(context, loc)
          : GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 0.8,
              ),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return _buildCompactChannelItem(context, channel, loc);
              },
            ),
    );
  }

  Widget _buildCompactChannelItem(BuildContext context, YoutubeChannel channel, AppLocalizations loc) {
    return TactileButton(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChannelFeedScreen(channel: channel)),
        );
      },
      child: Column(
        children: [
          Expanded(
            child: TactileCard(
              padding: const EdgeInsets.all(4),
              borderRadius: 100,
              child: CircleAvatar(
                radius: 40,
                backgroundImage: channel.thumbnailUrl.isNotEmpty ? NetworkImage(channel.thumbnailUrl) : null,
                backgroundColor: DadyTubeTheme.primaryContainer,
                child: channel.thumbnailUrl.isEmpty ? const Icon(Icons.tv_rounded, color: Colors.white, size: 30) : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            channel.name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.subscriptions_rounded, size: 80, color: DadyTubeTheme.primaryContainer),
          const SizedBox(height: 24),
          Text(
            loc.translate('no_channels'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              loc.translate('ask_parent_msg'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
