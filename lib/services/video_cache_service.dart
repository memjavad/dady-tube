import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'youtube_service.dart';

class VideoCacheService {
  static final VideoCacheService _instance = VideoCacheService._internal();
  factory VideoCacheService() => _instance;
  VideoCacheService._internal();

  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  final Map<String, _PersistentManifest> _manifestCache = {};
  static const int _maxCacheEntries = 50; 
  static const int _manifestTTLHours = 5; // 5 Hours to match YouTube link expiry

  Future<String> get _cachePath async {
    final directory = await getTemporaryDirectory();
    return '${directory.path}/video_cache';
  }

  /// Saves a specific stream URL to disk for high-speed reuse.
  Future<void> _persistStreamUrl(String videoId, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('persistent_stream_urls') ?? '{}';
      final Map<String, dynamic> data = json.decode(jsonStr);
      data[videoId] = {
        'url': url,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('persistent_stream_urls', json.encode(data));
    } catch (_) {}
  }

  /// Returns a valid cached stream URL if it exists and is not expired.
  Future<String?> getCachedStreamUrl(String videoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('persistent_stream_urls');
      if (jsonStr == null) return null;
      
      final Map<String, dynamic> data = json.decode(jsonStr);
      if (!data.containsKey(videoId)) return null;
      
      final entry = data[videoId];
      final url = entry['url'] as String;
      final timestamp = entry['timestamp'] as int;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp < 1000 * 60 * 60 * _manifestTTLHours) {
        return url;
      }
    } catch (_) {}
    return null;
  }

  /// Gets a cached manifest, or fetches and caches it if missing.
  Future<yt.StreamManifest> getManifest(String videoId) async {
    // 1. Check in-memory cache
    if (_manifestCache.containsKey(videoId)) {
      final cached = _manifestCache[videoId]!;
      if (!cached.isExpired) return cached.manifest;
    }

    // 2. Fetch fresh from YouTube
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    _manifestCache[videoId] = _PersistentManifest(manifest: manifest, timestamp: DateTime.now());
    
    // Persistence for "Instant Play"
    final bestStream = manifest.muxed.withHighestBitrate();
    if (bestStream != null) {
      _persistStreamUrl(videoId, bestStream.url.toString());
    }

    return manifest;
  }

  /// Background task to fetch a manifest to make future clicks instant.
  void prefetchManifest(String videoId) {
    getManifest(videoId).catchError((_) => null);
  }

  /// Returns a local file path if the video is cached, or null otherwise.
  Future<String?> getCachedVideoPath(String videoId) async {
    final path = await _cachePath;
    final file = File('$path/$videoId.mp4');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  /// Returns a set of all video IDs currently in the cache.
  Future<Set<String>> getCachedVideoIds() async {
    final path = await _cachePath;
    final dir = Directory(path);
    if (!(await dir.exists())) return {};

    final files = await dir.list().where((e) => e is File).cast<File>().toList();
    return files.map((f) => f.path.split('/').last.split('.').first).toSet();
  }

  /// Starts caching a video in the background.
  Future<void> cacheVideo(String videoId) async {
    final existing = await getCachedVideoPath(videoId);
    if (existing != null) return;

    final client = http.Client();
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.muxed.withHighestBitrate();
      if (streamInfo == null) return;

      final url = streamInfo.url;
      final totalSize = streamInfo.size.totalBytes;
      final cacheDir = await _cachePath;
      await Directory(cacheDir).create(recursive: true);
      
      final file = File('$cacheDir/$videoId.mp4');
      final raf = await file.open(mode: FileMode.write);
      
      // Parallel Turbo Cache
      const int segmentCount = 4;
      final int segmentSize = (totalSize / segmentCount).ceil();
      List<Future<void>> cacheTasks = [];

      for (int i = 0; i < segmentCount; i++) {
        final start = i * segmentSize;
        final end = (i == segmentCount - 1) ? totalSize - 1 : (i + 1) * segmentSize - 1;

        cacheTasks.add(() async {
          try {
            final response = await client.send(http.Request('GET', url)
              ..headers['Range'] = 'bytes=$start-$end');

            int currentPos = start;
            await for (final chunk in response.stream) {
              await raf.setPosition(currentPos);
              await raf.writeFrom(chunk);
              currentPos += chunk.length;
            }
          } catch (_) {}
        }());
      }

      await Future.wait(cacheTasks);
      await raf.close();
      await _manageCacheSize();
    } catch (e) {
      print('Video Cache Error (Parallel): $e');
    } finally {
      client.close();
    }
  }

  /// Caches just the first ~5 seconds of a video for instant start.
  Future<void> cachePreview(String videoId) async {
    // If full video is already cached, no need for preview
    if (await getCachedVideoPath(videoId) != null) return;
    
    final cacheDir = await _cachePath;
    final previewFile = File('$cacheDir/$videoId.preview');
    if (await previewFile.exists()) return;

    try {
      final manifest = await getManifest(videoId);
      final streamInfo = manifest.muxed.withHighestBitrate();
      if (streamInfo == null) return;

      await Directory(cacheDir).create(recursive: true);
      
      final stream = _yt.videos.streamsClient.get(streamInfo);
      final ios = previewFile.openWrite();
      
      // Approximately 1-2MB is usually enough for 5 seconds of 720p/360p
      int totalBytes = 0;
      const int maxBytes = 1524 * 1024; // ~1.5MB

      await for (final chunk in stream) {
        ios.add(chunk);
        totalBytes += chunk.length;
        if (totalBytes >= maxBytes) break;
      }
      
      await ios.close();
      print('Preview Cache: Saved 5s for $videoId');
    } catch (e) {
      print('Preview Cache Error: $e');
    }
  }

  /// Returns a local file path for a preview if it exists.
  Future<String?> getPreviewPath(String videoId) async {
    final path = await _cachePath;
    final file = File('$path/$videoId.preview');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  /// Ensures we don't exceed the storage limit.
  Future<void> _manageCacheSize() async {
    final path = await _cachePath;
    final dir = Directory(path);
    if (!(await dir.exists())) return;

    final files = await dir.list().where((e) => e is File).cast<File>().toList();
    if (files.length <= _maxCacheEntries) return;

    // Sort by last modified (oldest first)
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    // Delete the oldest ones until we're under the limit
    for (int i = 0; i < files.length - _maxCacheEntries; i++) {
      try {
        await files[i].delete();
      } catch (_) {}
    }
  }

  static const String _keyLastCacheDate = 'last_auto_cache_date';
  static const String _keyDailyCacheCount = 'daily_auto_cache_count';
  static const String _keyLastCacheTimestamp = 'last_auto_cache_timestamp';
  static const int _maxDailyCache = 3;

  /// Orchestrates smart background caching with night priority.
  Future<void> syncAutoCache(Map<String, List<YoutubeVideo>> allChannelVideos) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = "${now.year}-${now.month}-${now.day}";
    final lastDate = prefs.getString(_keyLastCacheDate) ?? "";
    
    int dailyCount = (lastDate == today) ? (prefs.getInt(_keyDailyCacheCount) ?? 0) : 0;
    
    if (dailyCount >= _maxDailyCache) {
      print('Smart Cache: Daily limit of $_maxDailyCache reached.');
      return;
    }

    final lastTimestamp = prefs.getInt(_keyLastCacheTimestamp) ?? 0;
    final timeSinceLastCache = now.millisecondsSinceEpoch - lastTimestamp;
    
    // Night priority: 11 PM to 5 AM
    final isNightTime = now.hour >= 23 || now.hour < 5;
    
    // Scheduling logic: 
    // - If night time, proceed (as long as it's been at least 1 hour since last cache to avoid bursts)
    // - If day time, only proceed if it's been at least 6 hours since the last cache
    bool shouldProceed = false;
    if (isNightTime) {
      shouldProceed = (timeSinceLastCache > 1000 * 60 * 60); // 1 hour
    } else {
      shouldProceed = (timeSinceLastCache > 1000 * 60 * 60 * 6); // 6 hours
    }

    if (!shouldProceed && lastTimestamp != 0) {
      print('Smart Cache: Too soon to cache again. (Last cache: ${DateTime.fromMillisecondsSinceEpoch(lastTimestamp)})');
      return;
    }

    // Pick the "best" video to cache: find the newest video across all channels that isn't cached yet
    List<YoutubeVideo> candidates = [];
    allChannelVideos.values.forEach((vids) => candidates.addAll(vids));
    candidates.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    final cachedIds = await getCachedVideoIds();
    YoutubeVideo? vToCache;
    
    for (var v in candidates) {
      if (!cachedIds.contains(v.id)) {
        vToCache = v;
        break;
      }
    }

    if (vToCache != null) {
      print('Smart Cache: Starting download for ${vToCache.title} (Night: $isNightTime)');
      
      // Update state before starting to avoid race conditions
      await prefs.setString(_keyLastCacheDate, today);
      await prefs.setInt(_keyDailyCacheCount, dailyCount + 1);
      await prefs.setInt(_keyLastCacheTimestamp, now.millisecondsSinceEpoch);

      // Start download
      cacheVideo(vToCache.id);
    }
  }

  void dispose() {
    _yt.close();
  }
}

class _PersistentManifest {
  final yt.StreamManifest manifest;
  final DateTime timestamp;

  _PersistentManifest({required this.manifest, required this.timestamp});

  bool get isExpired {
    return DateTime.now().difference(timestamp).inHours >= 5;
  }
}
