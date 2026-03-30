import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:convert';
import '../services/youtube_service.dart';
import '../services/video_cache_service.dart';
import '../services/database_service.dart';
import 'download_provider.dart';

class YoutubeChannel {
  final String id;
  final String name;
  final String thumbnailUrl;

  YoutubeChannel({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
  });

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

  // Cache for expensive getter computations
  List<YoutubeVideo>? _cachedAllVideos;
  List<YoutubeVideo>? _cachedShuffledVideos;

  void _invalidateVideoCache() {
    _cachedAllVideos = null;
    _cachedShuffledVideos = null;
  }

  List<YoutubeVideo> get allVideos {
    if (_cachedAllVideos != null) {
      return _cachedAllVideos!;
    }

    List<YoutubeVideo> all = [];
    final activeChannelIds = _channels.map((c) => c.id).toSet();

    _channelVideos.forEach((channelId, vids) {
      if (activeChannelIds.contains(channelId)) {
        all.addAll(vids);
      }
    });

    // Sort all videos by publishedAt descending
    all.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    _cachedAllVideos = all;
    return all;
  }

  /// Returns only videos that are playable right now (Offline or Online)
  Future<List<YoutubeVideo>> getAvailableVideos(
    DownloadProvider downloadProvider,
  ) async {
    final all = allVideos;
    if (!_isOffline) return all;

    final cachedIds = await VideoCacheService().getCachedVideoIds();
    final downloadedIds = downloadProvider.downloadedVideos
        .map((v) => v.id)
        .toSet();

    return all
        .where((v) => cachedIds.contains(v.id) || downloadedIds.contains(v.id))
        .toList();
  }

  List<YoutubeVideo> get shuffledVideos {
    if (_cachedShuffledVideos != null) {
      return _cachedShuffledVideos!;
    }

    final all = allVideos;
    if (all.isEmpty) return [];

    // Sort logic remains the same
    final newest = all.take(10).toList()..shuffle();
    final remaining = all.skip(10).toList()..shuffle();
    _cachedShuffledVideos = [...newest, ...remaining];
    return _cachedShuffledVideos!;
  }

  ChannelProvider() {
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final dbService = DatabaseService.instance;

    // Try loading channels from Database first
    _channels = await dbService.getChannels();

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

    if (_channels.isEmpty || (prefs.getBool('v2_5_migration_applied') ?? false) == false) {
      // Force reset or migrate curated list
      _channels = curatedChannels;
      await prefs.setBool('v2_5_migration_applied', true);
      for (var channel in _channels) {
        await dbService.insertChannel(channel);
      }
      
      // Attempt to migrate old JSON cache if it exists
      final oldVideosCache = prefs.getString('videos_cache');
      if (oldVideosCache != null) {
        try {
          final oldMap = await compute(_decodeVideoCache, oldVideosCache);
          for (var entry in oldMap.entries) {
            await dbService.insertOrUpdateVideos(entry.value);
          }
          await prefs.remove('videos_cache'); // Cleanup
        } catch (_) {}
      }
    }

    _invalidateVideoCache();

    // Load cached videos instantly from local DB
    _channelVideos = await dbService.getAllVideosMap(_channels.map((e) => e.id).toList());
    
    // Fast Boot: If we have data, we can start immediately
    if (_channelVideos.values.any((list) => list.isNotEmpty)) {
      _isInitialized = true;
      _initProgress = 1.0;
      _initStatusKey = "splash_ready";
      notifyListeners();

      // Refresh in background without blocking
      loadAllVideos(isBackground: true);
      _isLoading = false;
      return;
    }

    _isLoading = false;
    _initProgress = 0.1;
    _initStatusKey = "splash_preparing";
    notifyListeners();
    loadAllVideos();
  }

  Future<void> loadAllVideos({
    bool? autoCache,
    bool isBackground = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final shouldAutoCache =
        autoCache ?? prefs.getBool('auto_cache_enabled') ?? true;

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
              final newName = (info.name.isEmpty || info.name == 'Kid Channel')
                  ? channel.name
                  : info.name;
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
            // Save newly fetched videos to database (appends without duplicate issues)
            await DatabaseService.instance.insertOrUpdateVideos(vids);
            
            // Refetch the unified list of videos for this channel from DB
            _channelVideos[channel.id] = await DatabaseService.instance.getVideosForChannel(channel.id);
            _invalidateVideoCache();
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

  Future<void> removeChannel(String id) async {
    _channels.removeWhere((c) => c.id == id);
    _channelVideos.remove(id); // Important: clean up videos too
    _invalidateVideoCache();
    await DatabaseService.instance.deleteChannel(id);
    notifyListeners();
  }

  Future<void> addChannel(YoutubeChannel channel) async {
    if (!_channels.any((c) => c.id == channel.id)) {
      _channels.add(channel);
      _invalidateVideoCache();
      await DatabaseService.instance.insertChannel(channel);
      notifyListeners();
      loadAllVideos(isBackground: true);
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
  return decoded.map(
    (key, value) => MapEntry(
      key,
      (value as List).map((v) => YoutubeVideo.fromJson(v)).toList(),
    ),
  );
}
