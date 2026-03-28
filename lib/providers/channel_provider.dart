import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:convert';
import '../services/youtube_service.dart';
import '../services/video_cache_service.dart';
import 'download_provider.dart';

class YoutubeChannel {
  final String id;
  final String name;
  final String thumbnailUrl;

  YoutubeChannel({required this.id, required this.name, required this.thumbnailUrl});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'thumbnailUrl': thumbnailUrl,
  };

  factory YoutubeChannel.fromJson(Map<String, dynamic> json) => YoutubeChannel(
    id: json['id'],
    name: json['name'],
    thumbnailUrl: json['thumbnailUrl'],
  );
}

class ChannelProvider with ChangeNotifier {
  List<YoutubeChannel> _channels = [];
  Map<String, List<YoutubeVideo>> _channelVideos = {};
  bool _isLoading = false;
  bool _isOffline = false;
  
  // New: Initialization progress for Splash Screen
  double _initProgress = 0.0;
  String _initStatusKey = "splash_preparing"; // Changed to Key
  String _initStatusArg = "";
  bool _isInitialized = false;

  List<YoutubeChannel> get channels => _channels;
  Map<String, List<YoutubeVideo>> get channelVideos => _channelVideos;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  double get initProgress => _initProgress;
  String get initStatusKey => _initStatusKey;
  String get initStatusArg => _initStatusArg;
  bool get isInitialized => _isInitialized;

  List<YoutubeVideo> get allVideos {
    List<YoutubeVideo> all = [];
    final activeChannelIds = _channels.map((c) => c.id).toSet();
    
    _channelVideos.forEach((channelId, vids) {
      if (activeChannelIds.contains(channelId)) {
        all.addAll(vids);
      }
    });

    // Sort all videos by publishedAt descending
    all.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return all;
  }

  /// Returns only videos that are playable right now (Offline or Online)
  Future<List<YoutubeVideo>> getAvailableVideos(DownloadProvider downloadProvider) async {
    final all = allVideos;
    if (!_isOffline) return all;

    final cachedIds = await VideoCacheService().getCachedVideoIds();
    final downloadedIds = downloadProvider.downloadedVideos.map((v) => v.id).toSet();

    return all.where((v) => cachedIds.contains(v.id) || downloadedIds.contains(v.id)).toList();
  }

  List<YoutubeVideo> get shuffledVideos {
    final all = allVideos;
    if (all.isEmpty) return [];
    
    // Sort logic remains the same
    final newest = all.take(10).toList()..shuffle();
    final remaining = all.skip(10).toList()..shuffle();
    return [...newest, ...remaining];
  }

  ChannelProvider() {
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final channelsJson = prefs.getStringList('channels') ?? [];
    
    // Curated Channel List (Version 2.5 Global Health Verified)
    final curatedChannels = [
      YoutubeChannel(id: 'UCAfwGn6Xq-TscvdChnPrktQ', name: 'The Fixies بالعربية', thumbnailUrl: ''),
      YoutubeChannel(id: 'UCuQKih3Ac3NABADQKQdeV6A', name: 'Spacetoon', thumbnailUrl: ''),
      YoutubeChannel(id: 'UCOGBA-T3jCfOPey73FzsxCw', name: 'Nick Jr. Arabia', thumbnailUrl: ''),
      YoutubeChannel(id: 'UCNbmKQcBE3Sdx2HN6KGkxKw', name: 'Hello Maestro', thumbnailUrl: ''),
      YoutubeChannel(id: 'UCXGCkE7vRMkwQwLVHJPd8fQ', name: 'أوكتونوتس', thumbnailUrl: ''),
      YoutubeChannel(id: 'UCXQ3-_m82KAnh-U6brMmvrA', name: 'مايا النحلة', thumbnailUrl: ''),
      YoutubeChannel(id: 'UCBZLg-ixSGqEjh3ld7nSwLg', name: 'السنافر', thumbnailUrl: ''),
      YoutubeChannel(id: 'UC1ShKv0O7polu_tlhcqg4Xw', name: 'نقيب لابرادور', thumbnailUrl: ''),
      YoutubeChannel(id: 'UCvr9YT7AwMTxKDqou3e_OUQ', name: 'زاد الحروف', thumbnailUrl: ''),
      YoutubeChannel(id: 'UCT21_ci7c9PKYy9XZDHuJZg', name: 'Gecko\'s Garage Arabic', thumbnailUrl: ''),
      YoutubeChannel(id: 'UCqiIbqnJB0AVTg6Z6QnZNdw', name: 'مغامرات منصور', thumbnailUrl: ''),
      YoutubeChannel(id: 'UCpzp1_jpI3lfYy6eTW1kqhw', name: 'مدينة الأصدقاء', thumbnailUrl: ''),
    ];

    if (channelsJson.isEmpty || (prefs.getBool('v2_5_migration_applied') ?? false) == false) {
      // Force reset to curated list to repair "Empty World" content issues
      _channels = curatedChannels;
      await prefs.setBool('v2_5_migration_applied', true);
      await prefs.setBool('v2_2_migration_applied', true);
      await prefs.setBool('v2_1_migration_applied', true);
      await prefs.setBool('v2_migration_applied', true);
      await prefs.setStringList('channels', curatedChannels.map((c) => json.encode(c.toJson())).toList());
    } else {
      _channels = channelsJson
          .map((item) => YoutubeChannel.fromJson(json.decode(item)))
          .toList();
    }

    // Load cached videos in background to avoid skipping frames
    final videosCache = prefs.getString('videos_cache');
    final lastSync = prefs.getInt('last_sync_timestamp') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final isCacheStale = (now - lastSync) > 1000 * 60 * 60 * 4; // 4 hours

    if (videosCache != null) {
      _channelVideos = await compute(_decodeVideoCache, videosCache);
      
      // Fast Boot: If we have data, we can start immediately
      if (_channelVideos.isNotEmpty) {
        _isInitialized = true;
        _initProgress = 1.0;
        _initStatusKey = "splash_ready";
        notifyListeners();
        
        // Refresh in background if stale
        if (isCacheStale) {
          loadAllVideos(isBackground: true);
        }
        _isLoading = false;
        return; // Skip the blocking loadAllVideos
      }
    }

    _isLoading = false;
    _initProgress = 0.1;
    _initStatusKey = "splash_preparing";
    notifyListeners();
    loadAllVideos(); 
  }

  Future<void> loadAllVideos({bool? autoCache, bool isBackground = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final shouldAutoCache = autoCache ?? prefs.getBool('auto_cache_enabled') ?? true;

    // Only show shimmer if we don't have cached content
    if (_channelVideos.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    bool updated = false;
    int failCount = 0;

    // Parallel Discovery Engine: Fetch all 12 channels concurrently
    final List<Future<void>> discoveryTasks = [];
    int completedCount = 0;

    for (var i = 0; i < _channels.length; i++) {
      final index = i;
      discoveryTasks.add(() async {
        var channel = _channels[index];
        try {
          // Auto-heal missing thumbnails
          if (channel.thumbnailUrl.isEmpty) {
            final info = await YoutubeService.getChannelInfoById(channel.id);
            if (info != null && info.thumbnailUrl.isNotEmpty) {
              final newName = (info.name.isEmpty || info.name == 'Kid Channel') ? channel.name : info.name;
              _channels[index] = YoutubeChannel(
                id: channel.id,
                name: newName,
                thumbnailUrl: info.thumbnailUrl,
              );
              updated = true;
            }
          }

          final vids = await YoutubeService.fetchVideosForChannel(channel.id);
          if (vids.isNotEmpty) {
            vids.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
            _channelVideos[channel.id] = vids;
            updated = true;
          }
        } catch (e) {
          print('Failed to load channel ${channel.name}: $e');
          failCount++;
        } finally {
          completedCount++;
          // Update progress (Parallel safe) - Only if NOT background
          if (!isBackground) {
            _initProgress = 0.1 + (0.8 * (completedCount / _channels.length));
            _initStatusKey = "splash_finding";
            _initStatusArg = channel.name;
            notifyListeners();
          }
        }
      }());
    }

    await Future.wait(discoveryTasks);

    if (updated) {
       await _saveChannels(skipVideoReload: true);
    }

    // Finishing touches - Only if NOT background
    if (!isBackground) {
      _initProgress = 0.95;
      _initStatusKey = "splash_almost";
      _initStatusArg = "";
      notifyListeners();
    }

    // Detection of offline mode: if all channels failed and we have no videos, or if it seems like a global failure
    _isOffline = failCount > 0 && failCount == _channels.length;

    if (updated) {
      _saveVideosToCache();
      
      // Pre-fetch manifests for top videos
      final topVideos = allVideos.take(5);
      for (var video in topVideos) {
        VideoCacheService().prefetchManifest(video.id);
      }
    }

    _isLoading = false;
    _isInitialized = true;
    if (!isBackground) {
      _initProgress = 1.0;
      _initStatusKey = "splash_ready";
      _initStatusArg = "";
    }
    notifyListeners();
    
    if (updated) {
      _cacheTopPreviews();
      _precacheTopThumbnails();
    }
  }

  Future<void> _precacheTopThumbnails() async {
    final videos = shuffledVideos.take(12).toList();
    for (var video in videos) {
      if (video.thumbnailUrl.isNotEmpty) {
        DefaultCacheManager().downloadFile(video.thumbnailUrl);
      }
    }
  }

  Future<void> _cacheTopPreviews() async {
    final videos = shuffledVideos.take(7).toList();
    for (var video in videos) {
      VideoCacheService().cachePreview(video.id);
    }
  }

  Future<void> _saveVideosToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_channelVideos.map((key, value) => 
        MapEntry(key, value.map((v) => v.toJson()).toList())));
    await prefs.setString('videos_cache', encoded);
    await prefs.setInt('last_sync_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> removeChannel(String id) async {
    _channels.removeWhere((c) => c.id == id);
    _channelVideos.remove(id); // Important: clean up videos too
    await _saveChannels();
    _saveVideosToCache(); // Sync cache
    notifyListeners();
  }

  Future<void> addChannel(YoutubeChannel channel) async {
    if (!_channels.any((c) => c.id == channel.id)) {
      _channels.add(channel);
      await _saveChannels();
      notifyListeners();
    }
  }

  Future<void> _saveChannels({bool skipVideoReload = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('channels', _channels.map((c) => json.encode(c.toJson())).toList());
    if (!skipVideoReload) {
      loadAllVideos();
    }
  }

  Future<void> triggerBackgroundSync() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldAutoCache = prefs.getBool('auto_cache_enabled') ?? true;
    
    if (shouldAutoCache && _channelVideos.isNotEmpty) {
      VideoCacheService().syncAutoCache(_channelVideos);
    }
  }

  /// Predictive Pre-warming: Pre-fetches the manifest for the video physically following 
  /// the current one in the shuffled list.
  void prewarmNextVideo(String currentVideoId) {
    final list = shuffledVideos;
    final index = list.indexWhere((v) => v.id == currentVideoId);
    
    if (index != -1 && index < list.length - 1) {
      final nextVideo = list[index + 1];
      print('🚀 Predictive Pre-warming for: ${nextVideo.title}');
      VideoCacheService().prefetchManifest(nextVideo.id);
    }
  }
}

Map<String, List<YoutubeVideo>> _decodeVideoCache(String jsonString) {
  final Map<String, dynamic> decoded = json.decode(jsonString);
  return decoded.map((key, value) => 
      MapEntry(key, (value as List).map((v) => YoutubeVideo.fromJson(v)).toList()));
}
