import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';
import 'youtube_service.dart';
import 'video_cache_service.dart';

/// Headless callback executed by WorkManager in a separate background isolate.
Future<bool> nightlySyncTask(String task, Map<String, dynamic>? inputData) async {
  debugPrint('🌙 DadyTube: Nightly background caching task started at 3 AM constraints.');
  
  try {
    // 1. Initialize DB Service
    final dbService = DatabaseService.instance;
    
    // 2. Fetch subscribed channels from database
    final channels = await dbService.getChannels();
    if (channels.isEmpty) {
      debugPrint('🌙 DadyTube Night Sync: No subscribed channels found. Exiting.');
      return true;
    }

    // 3. For each channel, fetch latest videos, update DB, download top 2, and prune to 10
    for (var channel in channels) {
      debugPrint('🌙 DadyTube Night Sync: Syncing channel: ${channel.name}');
      
      try {
        // Fetch up to 10 latest videos from YouTube (automatically skips shorts & live streams)
        final fetchedVideos = await YoutubeService.fetchVideosForChannel(
          channel.id,
          limit: 10,
        );

        if (fetchedVideos.isEmpty) {
          debugPrint('🌙 DadyTube Night Sync: No new videos found for ${channel.name}.');
          continue;
        }

        // Insert new discoveries into local DB for offline access metadata
        await dbService.insertOrUpdateVideos(fetchedVideos);

        // Download the 2 latest videos for future offline rewatches
        final top2ToCache = fetchedVideos.take(2);
        for (var v in top2ToCache) {
          debugPrint('🌙 DadyTube Night Sync: Caching top video: ${v.title}');
          await VideoCacheService().cacheVideo(
            v.id,
            title: v.title,
            thumbnailUrl: v.thumbnailUrl,
            channelId: channel.id,
          );
        }

        // Group cached videos and prune older ones to keep at most 10 per channel
        await pruneVideosForChannel(channel.id, 10);

      } catch (e) {
        debugPrint('🌙 DadyTube Night Sync Error for channel ${channel.name}: $e');
      }
    }

    debugPrint('🌙 DadyTube: Nightly background caching task completed successfully.');
    return true;
  } catch (e) {
    debugPrint('🌙 DadyTube: Nightly background caching task failed: $e');
    return false;
  }
}

/// Prunes cached videos for a channel to keep at most [maxCount] videos.
Future<void> pruneVideosForChannel(String channelId, int maxCount) async {
  try {
    final videoCache = VideoCacheService();
    // Get local cache folder path
    // VideoCacheService._cachePath is a private getter, let's read the folder path
    // using custom path or getTemporaryDirectory directly.
    final directory = await getTemporaryDirectory();
    final cacheDirPath = '${directory.path}/video_cache';
    final dir = Directory(cacheDirPath);
    
    if (!await dir.exists()) return;

    final List<File> metaFiles = [];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.meta')) {
        metaFiles.add(entity);
      }
    }

    final List<Map<String, dynamic>> channelCacheEntries = [];
    for (var metaFile in metaFiles) {
      try {
        final content = await metaFile.readAsString();
        final Map<String, dynamic> data = json.decode(content);
        if (data['channelId'] == channelId) {
          final cachedAtStr = data['cachedAt'] as String?;
          final cachedAt = cachedAtStr != null ? DateTime.parse(cachedAtStr) : DateTime.fromMillisecondsSinceEpoch(0);
          // Video ID is file name without extension
          final videoId = metaFile.path.split(Platform.pathSeparator).last.replaceAll('.meta', '');
          channelCacheEntries.add({
            'videoId': videoId,
            'cachedAt': cachedAt,
            'metaFile': metaFile,
          });
        }
      } catch (_) {}
    }

    // If we exceed the maximum cached videos count, sort by cached date (oldest first) and delete
    if (channelCacheEntries.length > maxCount) {
      channelCacheEntries.sort((a, b) => (a['cachedAt'] as DateTime).compareTo(b['cachedAt'] as DateTime));
      
      final entriesToDelete = channelCacheEntries.take(channelCacheEntries.length - maxCount);
      for (var entry in entriesToDelete) {
        final videoId = entry['videoId'] as String;
        final mp4File = File('$cacheDirPath/$videoId.mp4');
        final metaFile = entry['metaFile'] as File;
        final previewFile = File('$cacheDirPath/$videoId.preview');

        try {
          if (await mp4File.exists()) await mp4File.delete();
          if (await metaFile.exists()) await metaFile.delete();
          if (await previewFile.exists()) await previewFile.delete();
          
          // Invalidate internal cached sets
          videoCache.clearCachedIdSet();
          debugPrint('🧹 Night Pruning: Deleted old video $videoId for channel $channelId');
        } catch (e) {
          debugPrint('⚠️ Prune delete failed for $videoId: $e');
        }
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error in channel pruning service: $e');
  }
}
