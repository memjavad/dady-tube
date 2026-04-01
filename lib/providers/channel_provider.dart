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
    _cachedBigFilteredVideos = null;
    _cachedPopularFilteredVideos = null;
    _cachedChannelFeedVideos = null;
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

  // Cache for filtered lists to prevent 60fps UI rebuild bottlenecks
  int _lastBigFilterHash = 0;
  List<YoutubeVideo>? _cachedBigFilteredVideos;

  int _lastPopularFilterHash = 0;
  List<YoutubeVideo>? _cachedPopularFilteredVideos;

  String? _lastChannelIdForFeed;
  int _lastBlockedKeywordsHashForFeed = 0;
  List<YoutubeVideo>? _cachedChannelFeedVideos;

  List<YoutubeVideo> getFilteredBigList({
    required bool isOffline,
    required List<YoutubeVideo> availableVideos,
    required List<String> blockedKeywords,
    required bool isNightTime,
  }) {
    final hash = Object.hash(
      isOffline,
      availableVideos.length,
      Object.hashAll(blockedKeywords),
      isNightTime,
      allVideos.length,
    );
    if (_cachedBigFilteredVideos != null && _lastBigFilterHash == hash) {
      return _cachedBigFilteredVideos!;
    }

    List<YoutubeVideo> videos = isOffline ? availableVideos : shuffledVideos;
    if (blockedKeywords.isNotEmpty) {
      videos = videos.where((video) {
        final title = video.title.toLowerCase();
        return !blockedKeywords.any((keyword) => title.contains(keyword));
      }).toList();
    }

    if (isNightTime) {
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

    _cachedBigFilteredVideos = videos;
    _lastBigFilterHash = hash;
    return videos;
  }

  List<YoutubeVideo> getFilteredPopularList({
    required String selectedWorld,
    required List<YoutubeVideo> downloadedVideos,
  }) {
    final hash = Object.hash(
      selectedWorld,
      downloadedVideos.length,
      allVideos.length,
    );
    if (_cachedPopularFilteredVideos != null &&
        _lastPopularFilterHash == hash) {
      return _cachedPopularFilteredVideos!;
    }

    var videos = allVideos;
    if (selectedWorld == 'Travel Mode') {
      videos = downloadedVideos;
    } else if (selectedWorld != 'All') {
      videos = videos
          .where(
            (v) => v.title.toLowerCase().contains(selectedWorld.toLowerCase()),
          )
          .toList();
    }

    _cachedPopularFilteredVideos = videos;
    _lastPopularFilterHash = hash;
    return videos;
  }

  // ⚡ Bolt: Memoize sorting to prevent O(N log N) execution on every UI build frame
  List<YoutubeVideo> getSortedAndFilteredChannelVideos(
    String channelId,
    List<String> blockedKeywords,
  ) {
    final keywordsHash = Object.hashAll(blockedKeywords);

    // Check if cache is valid
    if (_cachedChannelFeedVideos != null &&
        _lastChannelIdForFeed == channelId &&
        _lastBlockedKeywordsHashForFeed == keywordsHash) {
      return _cachedChannelFeedVideos!;
    }

    // Cache miss, recompute
    List<YoutubeVideo> videos = _channelVideos[channelId]?.toList() ?? [];

    if (blockedKeywords.isNotEmpty) {
      videos = videos.where((video) {
        final title = video.title.toLowerCase();
        return !blockedKeywords.any((keyword) => title.contains(keyword));
      }).toList();
    }

    videos.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    // Store in cache
    _lastChannelIdForFeed = channelId;
    _lastBlockedKeywordsHashForFeed = keywordsHash;
    _cachedChannelFeedVideos = videos;

    return videos;
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
      YoutubeChannel(
        id: 'UCAfwGn6Xq-TscvdChnPrktQ',
        name: 'The Fixies بالعربية',
        thumbnailUrl: '',
      ),
      YoutubeChannel(
        id: 'UCuQKih3Ac3NABADQKQdeV6A',
        name: 'Spacetoon',
        thumbnailUrl: '',
      ),
      YoutubeChannel(
        id: 'UCOGBA-T3jCfOPey73FzsxCw',
        name: 'Nick Jr. Arabia',
        thumbnailUrl: '',
      ),
      YoutubeChannel(
        id: 'UCNbmKQcBE3Sdx2HN6KGkxKw',
        name: 'Hello Maestro',
        thumbnailUrl: '',
      ),
      YoutubeChannel(
        id: 'UCXGCkE7vRMkwQwLVHJPd8fQ',
        name: 'أوكتونوتس',
        thumbnailUrl: '',
      ),
      YoutubeChannel(
        id: 'UCXQ3-_m82KAnh-U6brMmvrA',
        name: 'مايا النحلة',
        thumbnailUrl: '',
      ),
      YoutubeChannel(
        id: 'UCBZLg-ixSGqEjh3ld7nSwLg',
        name: 'السنافر',
        thumbnailUrl: '',
      ),
      YoutubeChannel(
        id: 'UC1ShKv0O7polu_tlhcqg4Xw',
        name: 'نقيب لابرادور',
        thumbnailUrl: '',
      ),
      YoutubeChannel(
        id: 'UCvr9YT7AwMTxKDqou3e_OUQ',
        name: 'زاد الحروف',
        thumbnailUrl: '',
      ),
      YoutubeChannel(
        id: 'UCT21_ci7c9PKYy9XZDHuJZg',
        name: 'Gecko\'s Garage Arabic',
        thumbnailUrl: '',
      ),
      YoutubeChannel(
        id: 'UCqiIbqnJB0AVTg6Z6QnZNdw',
        name: 'مغامرات منصور',
        thumbnailUrl: '',
      ),
      YoutubeChannel(
        id: 'UCpzp1_jpI3lfYy6eTW1kqhw',
        name: 'مدينة الأصدقاء',
        thumbnailUrl: '',
      ),
    ];

    if (_channels.isEmpty ||
        (prefs.getBool('v2_5_migration_applied') ?? false) == false) {
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
    _channelVideos = await dbService.getAllVideosMap(
      _channels.map((e) => e.id).toList(),
    );

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

          await YoutubeService.fetchVideosForChannel(
            channel.id,
            limit: 100, // Strictly limit to 100 per channel
            onVideosFetched: (chunk) async {
              // Save newly fetched videos to database piece-by-piece
              await DatabaseService.instance.insertOrUpdateVideos(chunk);

              // Update the in-memory map incrementally
              final existingVids = _channelVideos[channel.id] ?? [];
              final chunkIds = chunk.map((v) => v.id).toSet();

              // Simple way to avoid in-memory dupes before the next full reload
              final newInChunk = chunk
                  .where(
                    (v) => !existingVids.any((existing) => existing.id == v.id),
                  )
                  .toList();

              if (newInChunk.isNotEmpty) {
                _channelVideos[channel.id] = [...existingVids, ...newInChunk];
                _invalidateVideoCache();
                notifyListeners(); // Live update for Statistics tab
              }
            },
          );
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

  Future<void> forceSyncFull() async {
    // Perform a deep metadata sync first
    await loadAllVideos(isBackground: false);

    if (_channelVideos.isNotEmpty) {
      // Also perform a thorough auto-cache sync for links
      await VideoCacheService().syncAutoCache(
        _channelVideos,
        ignoreTimers: true,
        deep: true,
      );
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
