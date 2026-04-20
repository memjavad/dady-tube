import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/youtube_service.dart';
import '../services/video_cache_service.dart';
import '../services/database_service.dart';
import 'download_provider.dart';

class YoutubeChannel {
  final String id;
  final String name;
  final String thumbnailUrl;
  final String? localThumbnailPath;

  YoutubeChannel({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    this.localThumbnailPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'thumbnailUrl': thumbnailUrl,
    'localThumbnailPath': localThumbnailPath,
  };

  factory YoutubeChannel.fromJson(Map<String, dynamic> json) => YoutubeChannel(
    id: json['id'],
    name: json['name'],
    thumbnailUrl: json['thumbnailUrl'],
    localThumbnailPath: json['localThumbnailPath'],
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
  List<YoutubeVideo> _offlineReadyVideos = [];

  List<YoutubeChannel> get channels => _channels;
  Map<String, List<YoutubeVideo>> get channelVideos => _channelVideos;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  double get initProgress => _initProgress;
  String get initStatusKey => _initStatusKey;
  String get initStatusArg => _initStatusArg;
  bool get isInitialized => _isInitialized;
  List<YoutubeVideo> get offlineReadyVideos => _offlineReadyVideos;

  // Cache for expensive getter computations
  List<YoutubeVideo>? _cachedAllVideos;
  List<YoutubeVideo>? _cachedShuffledVideos;
  Map<String, YoutubeVideo>? _cachedVideoByIdMap;

  void _invalidateVideoCache() {
    _cachedAllVideos = null;
    _cachedShuffledVideos = null;
    _cachedVideoByIdMap = null;
    _cachedBigFilteredVideos = null;
    _cachedPopularFilteredVideos = null;
    _cachedChannelFeedVideos = null;
  }

  List<YoutubeVideo> get allVideos {
    if (_cachedAllVideos != null) {
      return _cachedAllVideos!;
    }

    List<YoutubeVideo> all = [];

    // Interleaving Logic (Round-Robin):
    // 1st video of each channel, then 2nd of each, and so on.
    final activeChannelIds = _channels.map((c) => c.id).toList();
    final List<List<YoutubeVideo>> groups = [];

    for (var id in activeChannelIds) {
      final vids = _channelVideos[id];
      if (vids != null && vids.isNotEmpty) {
        groups.add(vids);
      }
    }

    if (groups.isEmpty) return [];

    // Find the maximum number of videos in any single channel
    int maxVideos = groups.fold(
      0,
      (max, list) => list.length > max ? list.length : max,
    );

    for (int i = 0; i < maxVideos; i++) {
      for (var group in groups) {
        if (i < group.length) {
          all.add(group[i]);
        }
      }
    }

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

  /// Updates the list of videos ready for offline play (Manual + Auto-Cache)
  Future<void> updateOfflineVideos(DownloadProvider downloadProvider) async {
    final cachedIds = await VideoCacheService().getCachedVideoIds();
    final downloadedVideos = downloadProvider.downloadedVideos;
    final all = allVideos;

    // 1. Start with all manual downloads from the DownloadProvider
    List<YoutubeVideo> combined = List.from(downloadedVideos);

    // 2. Add all videos from the curated channel feed that have been auto-cached
    final manualIds = downloadedVideos.map((e) => e.id).toSet();
    for (var v in all) {
      if (cachedIds.contains(v.id) && !manualIds.contains(v.id)) {
        combined.add(v);
      }
    }

    _offlineReadyVideos = combined;

    // Also sort them by date (Newest first)
    _offlineReadyVideos.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    notifyListeners();
  }

  /// Helper to check if a specific video is ready for offline play
  bool isVideoOfflineReady(String videoId) {
    return _offlineReadyVideos.any((v) => v.id == videoId);
  }

  YoutubeVideo? getVideoById(String id) {
    if (_cachedVideoByIdMap == null) {
      _cachedVideoByIdMap = {};
      for (var vids in _channelVideos.values) {
        for (var v in vids) {
          _cachedVideoByIdMap![v.id] = v;
        }
      }
    }
    return _cachedVideoByIdMap![id];
  }

  YoutubeVideo? getNextVideo(String currentVideoId) {
    final list = shuffledVideos;
    final index = list.indexWhere((v) => v.id == currentVideoId);
    if (index != -1 && index < list.length - 1) {
      return list[index + 1];
    }
    return null;
  }

  List<YoutubeVideo> get shuffledVideos {
    if (_cachedShuffledVideos != null) {
      return _cachedShuffledVideos!;
    }

    // User requested specific ordering: "first the first video of each channal then secund video of each chanal"
    // To honor this, we disable the random shuffle and return the interleaved 'allVideos' list.
    final all = allVideos;
    _cachedShuffledVideos = all;
    return _cachedShuffledVideos!;
  }

  // Cache for filtered lists to prevent 60fps UI rebuild bottlenecks
  int _lastBigFilterHash = 0;
  List<YoutubeVideo>? _cachedBigFilteredVideos;

  int _lastPopularFilterHash = 0;
  List<YoutubeVideo>? _cachedPopularFilteredVideos;

  // ⚡ Bolt: Memoization Cache for Channel Feed Screen
  // Reduces O(N log N) sorting overhead during frequent background syncs by caching
  // the filtered and sorted list per channel. Avoids severe UI jank.
  String? _lastChannelIdForFeed;
  int _lastBlockedKeywordsHashForFeed = 0;
  List<YoutubeVideo>? _cachedChannelFeedVideos;

  List<YoutubeVideo> getFilteredChannelVideos({
    required String channelId,
    required List<String> blockedKeywords,
  }) {
    final keywordsHash = Object.hashAll(blockedKeywords);

    // ⚡ Bolt: Return cached result if data hasn't changed.
    if (_cachedChannelFeedVideos != null &&
        _lastChannelIdForFeed == channelId &&
        _lastBlockedKeywordsHashForFeed == keywordsHash) {
      return _cachedChannelFeedVideos!;
    }

    // ⚡ Bolt: Crucial to create a copy via .toList() to avoid mutating the original source
    // data below with .sort().
    List<YoutubeVideo> videos = _channelVideos[channelId]?.toList() ?? [];
    if (blockedKeywords.isNotEmpty) {
      videos = videos.where((video) {
        final title = video.title.toLowerCase();
        return !blockedKeywords.any((keyword) => title.contains(keyword));
      }).toList();
    }

    // Sort by latest first
    // ⚡ Bolt: This is an expensive O(N log N) operation, now safely memoized!
    videos.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    _lastChannelIdForFeed = channelId;
    _lastBlockedKeywordsHashForFeed = keywordsHash;
    _cachedChannelFeedVideos = videos;
    return videos;
  }

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
      // ⚡ Bolt: Single-pass O(N) partition to avoid O(N²) .where().contains() bottleneck
      final calmVideos = <YoutubeVideo>[];
      final otherVideos = <YoutubeVideo>[];
      for (final v in videos) {
        final title = v.title.toLowerCase();
        if (title.contains('learn') ||
            title.contains('music') ||
            title.contains('lullaby') ||
            title.contains('story')) {
          calmVideos.add(v);
        } else {
          otherVideos.add(v);
        }
      }
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

  // (getFilteredChannelVideos consolidated above)

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
          final allVideos = oldMap.values.expand((v) => v).toList();
          if (allVideos.isNotEmpty) {
            // ⚡ Bolt: Flatten list to fix N+1 query and process in a single batch
            await dbService.insertOrUpdateVideos(allVideos);
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

    // Initial check for missing local avatars (Persist permanently)
    _ensureChannelAvatars();
    // Fast Boot: If we have data, we can start immediately
    if (_channelVideos.values.any((list) => list.isNotEmpty)) {
      _isInitialized = true;
      _initProgress = 1.0;
      _initStatusKey = "splash_ready";
      notifyListeners();

      // Refresh in background without blocking
      loadAllVideos(isBackground: true);

      // ⚡ Fix 6: Always pre-warm previews and thumbnails from DB data, not just on network refresh
      _cacheTopPreviews();
      _precacheTopThumbnails();

      _isLoading = false;
      return;
    }

    _isLoading = false;
    _initProgress = 0.1;
    _initStatusKey = "splash_preparing";
    notifyListeners();
    loadAllVideos();
  }

  Future<void> loadAllVideos({bool isBackground = false}) async {
    // Ensure all channel avatars are cached permanently
    _ensureChannelAvatars();

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
            limit: 10, // Reduced from 50 to 10 to further minimize initial load
            onVideosFetched: (chunk) async {
              // Save newly fetched videos to database piece-by-piece
              await DatabaseService.instance.insertOrUpdateVideos(chunk);

              // Update the in-memory map incrementally
              final existingVids = _channelVideos[channel.id] ?? [];
              final chunkIds = chunk.map((v) => v.id).toSet();

              final existingIds = existingVids.map((e) => e.id).toSet();
              final newInChunk = chunk
                  .where((v) => !existingIds.contains(v.id))
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
      // Pre-fetch manifests for top videos (Reduced from 5 to 2)
      final topVideos = allVideos.take(2);
      for (var video in topVideos) {
        VideoCacheService().prefetchManifest(video.id);
      }

      _cacheTopPreviews();
      _precacheTopThumbnails();
    }

    _isLoading = false;
    _isInitialized = true;
    if (!isBackground) {
      _initProgress = 1.0;
      _initStatusKey = "splash_ready";
      _initStatusArg = "";
    }
    notifyListeners();
  }

  Future<void> _precacheTopThumbnails() async {
    final videos = shuffledVideos.take(6).toList(); // Reduced from 12
    for (var video in videos) {
      if (video.thumbnailUrl.isNotEmpty) {
        // Fire-and-forget with proper async error suppression
        // (.catchError can't be used here — it must return FileInfo, not void)
        () async {
          try {
            await DefaultCacheManager().downloadFile(video.thumbnailUrl);
          } catch (_) {}
        }();
      }
    }
  }

  Future<void> _cacheTopPreviews() async {
    final videos = shuffledVideos.take(3).toList(); // Reduced from 7
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

  /// 🖼️ Permanent Avatar Caching: Ensures all channels have a local profile picture.
  Future<void> _ensureChannelAvatars() async {
    final futures = <Future<void>>[];
    for (int i = 0; i < _channels.length; i++) {
      final channel = _channels[i];
      if (channel.localThumbnailPath == null &&
          channel.thumbnailUrl.isNotEmpty) {
        futures.add(_persistChannelAvatar(i));
      }
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> _persistChannelAvatar(int index) async {
    final channel = _channels[index];
    try {
      final response = await http
          .get(Uri.parse(channel.thumbnailUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final avatarsDir = Directory('${directory.path}/avatars');
        if (!await avatarsDir.exists()) {
          await avatarsDir.create(recursive: true);
        }

        final file = File('${avatarsDir.path}/${channel.id}.jpg');
        await file.writeAsBytes(response.bodyBytes);

        // Update model and DB
        final updatedChannel = YoutubeChannel(
          id: channel.id,
          name: channel.name,
          thumbnailUrl: channel.thumbnailUrl,
          localThumbnailPath: file.path,
        );

        _channels[index] = updatedChannel;
        await DatabaseService.instance.insertChannel(updatedChannel);
        debugPrint(
          '🖼️ Channel avatar persisted: ${channel.name} -> ${file.path}',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Error persisting channel avatar for ${channel.name}: $e');
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
