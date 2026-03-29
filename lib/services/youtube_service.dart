import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:xml/xml.dart';
import '../providers/channel_provider.dart';

class YoutubeService {
  // We'll use a simple method to try and resolve channel info
  // For a real production app, you'd use YouTube Data API or a more robust parser.
  static Future<YoutubeChannel?> getChannelInfo(String url) async {
    final ytExplode = yt.YoutubeExplode();
    try {
      final channel = await ytExplode.channels.getByVideo(
        url,
      ); // Can resolve from various URLs
      return YoutubeChannel(
        id: channel.id.value,
        name: channel.title,
        thumbnailUrl: channel.logoUrl,
      );
    } catch (e) {
      // Fallback to ID extraction if URL is a direct channel link
      try {
        if (url.contains('/channel/')) {
          final id = url.split('/channel/')[1].split('?')[0];
          return getChannelInfoById(id);
        }
      } catch (_) {}
      print('Error fetching channel info: $e');
    } finally {
      ytExplode.close();
    }
    return null;
  }

  static Future<YoutubeChannel?> getChannelInfoById(String id) async {
    final ytExplode = yt.YoutubeExplode();
    try {
      final channel = await ytExplode.channels.get(id);
      return YoutubeChannel(
        id: channel.id.value,
        name: channel.title,
        thumbnailUrl: channel.logoUrl,
      );
    } catch (e) {
      print('Error fetching channel info by ID with YoutubeExplode: $e');

      // Basic scraping fallback for metadata
      try {
        final url = 'https://www.youtube.com/channel/$id';
        final response = await http.get(Uri.parse(url));
        return _parseChannelResponse(response);
      } catch (_) {}
    } finally {
      ytExplode.close();
    }
    return null;
  }

  static YoutubeChannel? _parseChannelResponse(http.Response response) {
    if (response.statusCode == 200) {
      final body = response.body;

      // Try to use ytInitialData if available for better metadata
      if (body.contains('ytInitialData = ')) {
        try {
          final jsonStr = body
              .split('ytInitialData = ')[1]
              .split(';</script>')[0];
          final data = json.decode(jsonStr);

          final metadata = data['metadata']?['channelMetadataRenderer'];
          if (metadata != null) {
            final name = metadata['title'];
            final id = metadata['externalId'] ?? 'unknown';
            final thumb = metadata['avatar']?['thumbnails']?.last['url'] ?? '';

            if (id != 'unknown') {
              return YoutubeChannel(
                id: id,
                name: name ?? '',
                thumbnailUrl: thumb,
              );
            }
          }
        } catch (e) {
          print('Error parsing channel ytInitialData: $e');
        }
      }

      // Fallback to basic scraping
      String channelName = '';
      if (body.contains('<title>')) {
        channelName = body
            .split('<title>')[1]
            .split('</title>')[0]
            .replaceAll(' - YouTube', '');
      }

      String channelId = 'unknown';
      if (body.contains('channelId":"')) {
        channelId = body.split('channelId":"')[1].split('"')[0];
      } else if (body.contains('itemprop="channelId" content="')) {
        channelId = body
            .split('itemprop="channelId" content="')[1]
            .split('"')[0];
      } else if (body.contains('"browseId":"')) {
        channelId = body.split('"browseId":"')[1].split('"')[0];
      }

      String thumbUrl = '';
      if (body.contains('"avatar":{"thumbnails":[{"url":"')) {
        thumbUrl = body
            .split('"avatar":{"thumbnails":[{"url":"')[1]
            .split('"')[0];
      }

      if (channelId != 'unknown') {
        return YoutubeChannel(
          id: channelId,
          name: channelName,
          thumbnailUrl: thumbUrl,
        );
      }
    }
    return null;
  }

  static Future<List<YoutubeVideo>> fetchVideosForChannel(
    String channelId,
  ) async {
    final ytExplode = yt.YoutubeExplode();
    print('🔍 Fetching videos for: $channelId');
    try {
      // Phase 1: High Fidelity - YoutubeExplode
      final List<YoutubeVideo> videos = [];
      final uploads = ytExplode.channels.getUploads(channelId);

      await for (final video in uploads.take(30)) {
        videos.add(
          YoutubeVideo(
            id: video.id.value,
            title: video.title,
            thumbnailUrl: video.thumbnails.highResUrl,
            channelId: channelId,
            publishedAt: video.uploadDate ?? DateTime.now(),
          ),
        );
      }

      if (videos.isNotEmpty) {
        print('✅ Stage 1 (Explode) Success: ${videos.length} videos');
        return videos;
      }
    } catch (e) {
      print('❌ Stage 1 (Explode) Failed: $e');
    } finally {
      ytExplode.close();
    }

    // Phase 2: Rapid Fallback - Scraping
    try {
      final scrapeResults = await _fetchVideosViaScraping(channelId);
      if (scrapeResults.isNotEmpty) {
        print('✅ Stage 2 (Scraping) Success: ${scrapeResults.length} videos');
        return scrapeResults;
      }
    } catch (e) {
      print('❌ Stage 2 (Scraping) Failed: $e');
    }

    // Phase 3: Ultimate Fallback - RSS
    try {
      final url =
          'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId&hl=ar&gl=IQ';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final entries = document.findAllElements('entry');

        final videos = entries.map((entry) {
          final title = entry.findElements('title').first.innerText;
          final videoId = entry.findElements('yt:videoId').first.innerText;
          final mediaGroup = entry.findElements('media:group').first;
          final thumbnailUrl =
              mediaGroup
                  .findElements('media:thumbnail')
                  .first
                  .getAttribute('url') ??
              '';

          return YoutubeVideo(
            id: videoId,
            title: title,
            thumbnailUrl: thumbnailUrl,
            channelId: channelId,
            publishedAt:
                DateTime.tryParse(
                  entry.findElements('published').first.innerText,
                ) ??
                DateTime.now(),
          );
        }).toList();

        if (videos.isNotEmpty) {
          print('✅ Stage 3 (RSS) Success: ${videos.length} videos');
          return videos;
        }
      }
    } catch (e) {
      print('❌ Stage 3 (RSS) Failed: $e');
    }

    print('🛑 ALL STAGES FAILED for $channelId');
    return [];
  }

  static Future<List<YoutubeVideo>> _fetchVideosViaScraping(
    String channelId,
  ) async {
    // Try both /channel/ID and /@handle if we can find it
    // For now, use the ID-based URL as it's most reliable for scraping
    final url = 'https://www.youtube.com/channel/$channelId/videos?hl=ar&gl=IQ';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Accept-Language': 'ar-IQ,ar;q=0.9,en-US;q=0.8,en;q=0.7',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
    );

    if (response.statusCode != 200) return [];

    final body = response.body;
    if (!body.contains('ytInitialData = ')) return [];

    final jsonStr = body.split('ytInitialData = ')[1].split(';</script>')[0];
    return compute(_parseVideosJson, _ParseParams(jsonStr, channelId));
  }

  static List<YoutubeVideo> _parseVideosJson(_ParseParams params) {
    final data = json.decode(params.jsonStr);
    final String channelId = params.channelId;
    List<YoutubeVideo> videos = [];

    try {
      final tabs = data['contents']?['twoColumnBrowseResultsRenderer']?['tabs'];
      if (tabs == null) return [];

      var videosTabContent;
      for (var tab in tabs) {
        final tabRenderer = tab['tabRenderer'];
        if (tabRenderer != null &&
            (tabRenderer['title'] == 'Videos' ||
                tabRenderer['title'] == 'فيديوهات' ||
                tabRenderer['selected'] == true)) {
          videosTabContent = tabRenderer['content'];
          if (videosTabContent != null) break;
        }
      }

      if (videosTabContent == null) return [];

      final gridItems =
          videosTabContent['richGridRenderer']?['contents'] ??
          videosTabContent['sectionListRenderer']?['contents']?[0]?['itemSectionRenderer']?['contents']?[0]?['gridRenderer']?['items'];

      if (gridItems == null) return [];

      for (var item in gridItems) {
        final videoRenderer =
            item['richItemRenderer']?['content']?['videoRenderer'] ??
            item['gridVideoRenderer'];
        if (videoRenderer == null) continue;

        final videoId = videoRenderer['videoId'];
        final title =
            videoRenderer['title']?['runs']?[0]?['text'] ??
            videoRenderer['title']?['simpleText'] ??
            'Unknown Title';

        final thumbnails = videoRenderer['thumbnail']?['thumbnails'];
        final thumbUrl = thumbnails != null && thumbnails.isNotEmpty
            ? thumbnails.last['url']
            : '';

        videos.add(
          YoutubeVideo(
            id: videoId,
            title: title,
            thumbnailUrl: thumbUrl,
            channelId: channelId,
            publishedAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      print('Error parsing ytInitialData JSON in isolate: $e');
    }

    return videos;
  }

  static String getOptimizedThumbnail(String originalUrl, bool turboMode) {
    if (!turboMode) return originalUrl;

    // Convert high-res/max-res to medium-res for data saving
    if (originalUrl.contains('hqdefault.jpg'))
      return originalUrl.replaceFirst('hqdefault.jpg', 'mqdefault.jpg');
    if (originalUrl.contains('sddefault.jpg'))
      return originalUrl.replaceFirst('sddefault.jpg', 'mqdefault.jpg');
    if (originalUrl.contains('maxresdefault.jpg'))
      return originalUrl.replaceFirst('maxresdefault.jpg', 'mqdefault.jpg');

    return originalUrl;
  }
}

class YoutubeVideo {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String channelId;
  final DateTime publishedAt;

  YoutubeVideo({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.channelId,
    required this.publishedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'thumbnailUrl': thumbnailUrl,
    'channelId': channelId,
    'publishedAt': publishedAt.toIso8601String(),
  };

  factory YoutubeVideo.fromJson(Map<String, dynamic> json) => YoutubeVideo(
    id: json['id'],
    title: json['title'],
    thumbnailUrl: json['thumbnailUrl'],
    channelId: json['channelId'],
    publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
  );
}

class _ParseParams {
  final String jsonStr;
  final String channelId;
  _ParseParams(this.jsonStr, this.channelId);
}
