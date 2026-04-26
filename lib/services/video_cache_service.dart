import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'youtube_service.dart';
import 'youtube_client_service.dart';

bool _isUrlExpired(String url) {
  try {
    final uri = Uri.parse(url);
    int? expireSeconds;
    final expireQuery = uri.queryParameters['expire'];
    if (expireQuery != null) {
      expireSeconds = int.tryParse(expireQuery);
    } else {
      final pathSegments = uri.pathSegments;
      final expireIndex = pathSegments.indexOf('expire');
      if (expireIndex != -1 && expireIndex + 1 < pathSegments.length) {
        expireSeconds = int.tryParse(pathSegments[expireIndex + 1]);
      }
    }
    if (expireSeconds != null) {
      final expireDate = DateTime.fromMillisecondsSinceEpoch(
        expireSeconds * 1000,
      );
      // 10 minute safety buffer
      return DateTime.now().isAfter(
        expireDate.subtract(const Duration(minutes: 10)),
      );
    }
  } catch (_) {}
  return false;
}

class VideoCacheService {
  static final VideoCacheService _instance = VideoCacheService._internal();
  factory VideoCacheService() => _instance;
  VideoCacheService._internal();

  yt.YoutubeExplode get _yt => YoutubeClientService().client;
  final Map<String, _PersistentManifest> _manifestCache = {};
  static const int _maxCacheEntries =
      25; // Halved from 50 for reduced footprint
  static const int _manifestTTLHours =
      5; // 5 Hours to match YouTube link expiry

  // ⚡ Fix 1: In-memory path cache — resolves once per session, then instant
  String? _resolvedCachePath;

  Future<String> get _cachePath async {
    if (_resolvedCachePath != null) return _resolvedCachePath!;
    final directory = await getTemporaryDirectory();
    _resolvedCachePath = '${directory.path}/video_cache';
    return _resolvedCachePath!;
  }

  // ⚡ Fix 2: In-memory stream URL cache — reads SharedPrefs only once per video
  final Map<String, _CachedUrl> _streamUrlMemCache = {};

  /// Sanitizes the video ID to prevent path traversal vulnerabilities.
  String _sanitizeId(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  // Backwards compatibility for Bolt code and visible for testing
  String sanitizeVideoId(String id) => _sanitizeId(id);

  /// Saves a specific stream URL to disk for high-speed reuse.
  Future<void> _persistStreamUrl(String videoId, String url) async {
    try {
      // Store in memory immediately (no async wait needed for next read)
      _streamUrlMemCache[videoId] = _CachedUrl(
        url: url,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

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
  /// ⚡ Fix 2: Checks in-memory cache first — zero disk I/O on hot path.
  Future<String?> getCachedStreamUrl(String videoId) async {
    // 1. Check memory first (INSTANT — no I/O)
    final mem = _streamUrlMemCache[videoId];
    if (mem != null && !mem.isExpired) return mem.url;

    // 2. Only fall through to disk if not in memory
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('persistent_stream_urls');
      if (jsonStr == null) return null;

      final Map<String, dynamic> data = json.decode(jsonStr);
      if (!data.containsKey(videoId)) return null;

      final entry = data[videoId];
      final url = entry['url'] as String;
      final timestamp = entry['timestamp'] as int;

      if (_isUrlExpired(url)) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp < 1000 * 60 * 60 * _manifestTTLHours) {
        // Populate memory cache so next access is instant
        _streamUrlMemCache[videoId] = _CachedUrl(
          url: url,
          timestamp: timestamp,
        );
        return url;
      }
    } catch (_) {}
    return null;
  }

  final Map<String, Future<yt.StreamManifest>> _activeFetches = {};

  /// Gets a cached manifest, or fetches and caches it if missing.
  Future<yt.StreamManifest> getManifest(String videoId) async {
    // 1. Check in-memory cache
    if (_manifestCache.containsKey(videoId)) {
      final cached = _manifestCache[videoId]!;
      if (!cached.isExpired) return cached.manifest;
    }

    // 1.5. Deduplicate Race Conditions (JIT taps vs Background Queue)
    if (_activeFetches.containsKey(videoId)) {
      return await _activeFetches[videoId]!;
    }

    // 2. Fetch fresh from YouTube and broadcast the Future to any concurrent callers
    final fetchFuture = _yt.videos.streamsClient.getManifest(videoId);
    _activeFetches[videoId] = fetchFuture;

    try {
      final manifest = await fetchFuture;
      _manifestCache[videoId] = _PersistentManifest(
        manifest: manifest,
        timestamp: DateTime.now(),
      );

      // Persistence for "Instant Play"
      final bestStream = manifest.muxed.withHighestBitrate();
      if (bestStream != null) {
        _persistStreamUrl(videoId, bestStream.url.toString());
      }

      return manifest;
    } on yt.VideoUnplayableException catch (e) {
      debugPrint('🚫 Video Unplayable: $videoId - $e');
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Manifest Fetch Error: $videoId - $e');
      rethrow;
    } finally {
      _activeFetches.remove(videoId);
    }
  }

  // ⚡ Performance Prioritization: Pause all background tasks during video startup
  bool _isBackgroundPaused = false;
  final Set<http.Client> _activeClients = {};

  void pauseBackgroundOperations() {
    _isBackgroundPaused = true;

    // Forcefully terminate all in-progress parallel downloads to instantly free bandwidth
    for (var client in _activeClients) {
      try {
        client.close();
      } catch (_) {}
    }
    _activeClients.clear();
  }

  void resumeBackgroundOperations() {
    if (!_isBackgroundPaused) return;
    _isBackgroundPaused = false;
    _processManifestQueue();
  }

  Future<void> _waitUntilResumed() async {
    while (_isBackgroundPaused) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  bool _isFetchingManifest = false;
  final List<String> _manifestFetchQueue = [];
  final Set<String> _manifestQueueSet = {};

  /// Background task to fetch a manifest to make future clicks instant.
  void prefetchManifest(String videoId) {
    if (_manifestCache.containsKey(videoId)) {
      final cached = _manifestCache[videoId]!;
      if (!cached.isExpired) return;
    }

    if (!_manifestQueueSet.contains(videoId)) {
      _manifestQueueSet.add(videoId);
      _manifestFetchQueue.add(videoId);
      _processManifestQueue();
    }
  }

  Future<void> _processManifestQueue() async {
    if (_isFetchingManifest ||
        _manifestFetchQueue.isEmpty ||
        _isBackgroundPaused)
      return;

    _isFetchingManifest = true;
    final videoId = _manifestFetchQueue.removeAt(0);
    _manifestQueueSet.remove(videoId);

    try {
      final cachedUrl = await getCachedStreamUrl(videoId);
      if (cachedUrl == null) {
        final manifest = await getManifest(videoId);
        // ⚡ Socket Warming: Perform a tiny HEAD request to the stream server to warm TCP/TLS
        try {
          final bestStream = manifest.muxed.withHighestBitrate();
          final warmUrl = bestStream.url;
          // Trigger a HEAD request in background, don't await the body
          YoutubeClientService().httpClient
              .head(warmUrl)
              .timeout(const Duration(seconds: 3))
              .then((_) {
                debugPrint('🔥 Socket Warmed for $videoId');
              })
              .catchError((_) {});
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (_) {
    } finally {
      _isFetchingManifest = false;
      _processManifestQueue();
    }
  }

  /// Helper method to return an existing file path based on video ID and extension.
  Future<String?> _getExistingFilePath(String videoId, String extension) async {
    try {
      final path = await _cachePath;
      final sanitizedId = _sanitizeId(videoId);
      final file = File('$path/$sanitizedId$extension');
      if (await file.exists()) {
        final stat = await file.stat();
        if (stat.size > 0) {
          return file.path;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Returns a local file path if the video is cached, or null otherwise.
  Future<String?> getCachedVideoPath(String videoId) async {
    return _getExistingFilePath(videoId, '.mp4');
  }

  // ⚡ Fix 5: In-memory cached video ID set — scans disk only once per session
  Set<String>? _cachedVideoIdSet;

  void _invalidateCachedIdSet() => _cachedVideoIdSet = null;

  /// Returns a set of all video IDs currently in the cache.
  Future<Set<String>> getCachedVideoIds() async {
    // Return cached set immediately if available
    if (_cachedVideoIdSet != null) return _cachedVideoIdSet!;

    final path = await _cachePath;
    final dir = Directory(path);
    if (!(await dir.exists())) {
      _cachedVideoIdSet = {};
      return _cachedVideoIdSet!;
    }

    final Set<String> ids = {};
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.mp4')) {
        final name = entity.path.split(Platform.pathSeparator).last;
        ids.add(name.replaceAll('.mp4', ''));
      }
    }
    _cachedVideoIdSet = ids;
    return _cachedVideoIdSet!;
  }

  /// Starts caching a video in the background.
  /// ⚡ Fix 3: Reuses in-memory manifest. Fix 7: Writes metadata sidecar.
  Future<void> cacheVideo(
    String videoId, {
    String title = '',
    String thumbnailUrl = '',
    String channelId = '',
  }) async {
    await _waitUntilResumed(); // Yield to prioritized playback
    final existing = await getCachedVideoPath(videoId);
    if (existing != null) return;

    final client = http.Client();
    _activeClients.add(client);
    File? file;
    try {
      // ⚡ Fix 3: Use cached manifest instead of fetching a new one
      final manifest = await getManifest(videoId);
      final streamInfo = manifest.muxed.withHighestBitrate();

      final url = streamInfo.url;
      final totalSize = streamInfo.size.totalBytes;
      final cacheDir = await _cachePath;
      await Directory(cacheDir).create(recursive: true);

      final sanitizedId = _sanitizeId(videoId);
      file = File('$cacheDir/$sanitizedId.mp4');

      // Parallel Turbo Cache — 2 concurrent connections (Halved from 4 for footprint)
      const int segmentCount = 2;
      final int segmentSize = (totalSize / segmentCount).ceil();
      List<Future<void>> cacheTasks = [];
      bool hasError = false;

      for (int i = 0; i < segmentCount; i++) {
        final start = i * segmentSize;
        final end = (i == segmentCount - 1)
            ? totalSize - 1
            : (i + 1) * segmentSize - 1;
        final partFile = File('${file.path}.part$i');

        cacheTasks.add(() async {
          IOSink? sink;
          try {
            final response = await client
                .send(
                  http.Request('GET', url)
                    ..headers['Range'] = 'bytes=$start-$end',
                )
                .timeout(const Duration(seconds: 30));

            sink = partFile.openWrite();
            await for (final chunk in response.stream) {
              if (_isBackgroundPaused) {
                // Abort chunk processing if paused
                break;
              }
              sink.add(chunk);
            }
            await sink.flush();
            await sink.close();
          } catch (_) {
            hasError = true;
            if (sink != null) {
              try {
                await sink.close();
              } catch (_) {}
            }
          }
        }());
      }

      await Future.wait(cacheTasks);

      if (_isBackgroundPaused || hasError) {
        // We aborted mid-download or failed. Delete the incomplete parts.
        for (int i = 0; i < segmentCount; i++) {
          final partFile = File('${file.path}.part$i');
          if (await partFile.exists()) {
            try {
              await partFile.delete();
            } catch (_) {}
          }
        }
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
        return; // Exit early, do not mark as cached
      }

      // Stitch parts together sequentially
      final raf = await file.open(mode: FileMode.write);
      try {
        for (int i = 0; i < segmentCount; i++) {
          final partFile = File('${file.path}.part$i');
          if (await partFile.exists()) {
            final stream = partFile.openRead();
            await for (final chunk in stream) {
              await raf.writeFrom(chunk);
            }
            await partFile.delete();
          }
        }
        await raf.flush(); // Added flush before close for reliability
      } finally {
        await raf.close();
      }

      // ⚡ Fix 5: Invalidate cached ID set so next read picks up this new file
      _invalidateCachedIdSet();

      // ⚡ Fix 7: Write metadata sidecar
      if (title.isNotEmpty) {
        await _writeMetaSidecar(
          cacheDir,
          sanitizedId,
          title: title,
          thumbnailUrl: thumbnailUrl,
          channelId: channelId,
        );
      }

      await _manageCacheSize();
    } catch (e) {
      debugPrint('Video Cache Error (Parallel): $e');
    } finally {
      client.close();
      _activeClients.remove(client);
    }
  }

  /// Caches just the first ~1.5MB of a video for instant start preview.
  Future<void> cachePreview(String videoId) async {
    // If full video is already cached, no need for preview
    if (await getCachedVideoPath(videoId) != null) return;

    final cacheDir = await _cachePath;
    final sanitizedId = _sanitizeId(videoId);
    final previewFile = File('$cacheDir/$sanitizedId.preview');
    if (await previewFile.exists()) return;

    try {
      // ⚡ Fix 6: Reuses in-memory manifest if available
      final manifest = await getManifest(videoId);
      final streamInfo = manifest.muxed.withHighestBitrate();

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

      await ios.flush();
      await ios.close();
    } catch (e) {
      debugPrint('Preview Cache Error: $e');
    }
  }

  /// Returns a local file path for a preview if it exists.
  Future<String?> getPreviewPath(String videoId) async {
    return _getExistingFilePath(videoId, '.preview');
  }

  /// Ensures we don't exceed the storage limit.
  Future<void> _manageCacheSize() async {
    final path = await _cachePath;
    final dir = Directory(path);
    if (!(await dir.exists())) return;

    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.mp4'))
        .cast<File>()
        .toList();
    if (files.length <= _maxCacheEntries) return;

    // ⚡ Bolt: Use Schwartzian transform to avoid O(N log N) blocking disk I/O
    // lastModifiedSync() reads the disk. Doing it inside .sort() calls it multiple times per element.
    final filesWithStats = files
        .map((f) => (file: f, modified: f.lastModifiedSync()))
        .toList();
    filesWithStats.sort((a, b) => a.modified.compareTo(b.modified));

    final sortedFiles = filesWithStats.map((e) => e.file).toList();

    for (int i = 0; i < sortedFiles.length - _maxCacheEntries; i++) {
      try {
        await sortedFiles[i].delete();
        // Also delete the associated sidecar files
        final base = sortedFiles[i].path.replaceAll('.mp4', '');
        final metaFile = File('$base.meta');
        if (await metaFile.exists()) await metaFile.delete();
        final previewFile = File('$base.preview');
        if (await previewFile.exists()) await previewFile.delete();
      } catch (_) {}
    }
    // Invalidate set after deletion
    _invalidateCachedIdSet();
  }

  static const String _keyLastCacheDate = 'last_auto_cache_date';
  static const String _keyDailyCacheCount = 'daily_auto_cache_count';
  static const String _keyLastCacheTimestamp = 'last_auto_cache_timestamp';
  static const int _maxDailyCache = 1; // Halved from 2 for footprint reduction

  /// Orchestrates smart background caching with night priority.
  Future<void> syncAutoCache(
    Map<String, List<YoutubeVideo>> allChannelVideos, {
    bool ignoreTimers = false,
    bool deep = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = "${now.year}-${now.month}-${now.day}";
    final lastDate = prefs.getString(_keyLastCacheDate) ?? "";

    int dailyCount = (lastDate == today)
        ? (prefs.getInt(_keyDailyCacheCount) ?? 0)
        : 0;

    if (!ignoreTimers && !deep && dailyCount >= _maxDailyCache) {
      debugPrint('Smart Cache: Daily limit of $_maxDailyCache reached.');
      return;
    }

    final lastTimestamp = prefs.getInt(_keyLastCacheTimestamp) ?? 0;
    final timeSinceLastCache = now.millisecondsSinceEpoch - lastTimestamp;

    // Night priority: 11 PM to 5 AM
    final isNightTime = now.hour >= 23 || now.hour < 5;

    bool shouldProceed = false;
    if (isNightTime) {
      shouldProceed = (timeSinceLastCache > 1000 * 60 * 60 * 2); // 2 hours
    } else {
      shouldProceed = (timeSinceLastCache > 1000 * 60 * 60 * 12); // 12 hours
    }

    if (!ignoreTimers && !deep && !shouldProceed && lastTimestamp != 0) {
      debugPrint(
        'Smart Cache: Too soon to cache again. (Last cache: ${DateTime.fromMillisecondsSinceEpoch(lastTimestamp)})',
      );
      return;
    }

    // Step 1: Video File Caching (Heavy Downloads)
    if (!deep) {
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
        debugPrint(
          'Smart Cache: Starting download for ${vToCache.title} (Night: $isNightTime)',
        );
        await prefs.setString(_keyLastCacheDate, today);
        await prefs.setInt(_keyDailyCacheCount, dailyCount + 1);
        await prefs.setInt(_keyLastCacheTimestamp, now.millisecondsSinceEpoch);

        cacheVideo(
          vToCache.id,
          title: vToCache.title,
          thumbnailUrl: vToCache.thumbnailUrl,
          channelId: vToCache.channelId,
        );
      }
    }

    // Step 2: Instant Play Links Pre-fetching (Manifests only)
    final manifestLimit = deep
        ? 100
        : 2; // Halved from Bolt (original 50:1 -> 100:2)
    debugPrint(
      '🚀 Pre-fetching Instant Play Links (Limit: $manifestLimit per channel)',
    );

    for (var channelVids in allChannelVideos.values) {
      await _waitUntilResumed();
      final topVids = channelVids.take(manifestLimit);
      for (var v in topVids) {
        prefetchManifest(v.id);
      }
    }
  }

  /// Writes metadata sidecar for cached videos.
  Future<void> _writeMetaSidecar(
    String cacheDir,
    String sanitizedId, {
    required String title,
    required String thumbnailUrl,
    required String channelId,
  }) async {
    try {
      final metaFile = File('$cacheDir/$sanitizedId.meta');
      final metaData = {
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'channelId': channelId,
        'cachedAt': DateTime.now().toIso8601String(),
      };
      await metaFile.writeAsString(json.encode(metaData));
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getCacheStatistics() async {
    int totalBytes = 0;
    int mp4Count = 0;
    int previewCount = 0;
    int urlCount = 0;

    try {
      final path = await _cachePath;
      final dir = Directory(path);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File) {
            totalBytes += await entity.length();
            if (entity.path.endsWith('.mp4')) mp4Count++;
            if (entity.path.endsWith('.preview')) previewCount++;
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('persistent_stream_urls');
      if (jsonStr != null) {
        final Map<String, dynamic> data = json.decode(jsonStr);
        urlCount = data.length;
      }
    } catch (_) {}

    return {
      'totalBytes': totalBytes,
      'mp4Count': mp4Count,
      'previewCount': previewCount,
      'urlCount': urlCount,
      'memCacheCount': _manifestCache.length,
      'streamUrlMemCacheCount': _streamUrlMemCache.length,
    };
  }

  Future<void> clearAllCache() async {
    try {
      final path = await _cachePath;
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('persistent_stream_urls');
      // Clear all in-memory caches
      _streamUrlMemCache.clear();
      _manifestCache.clear();
      _cachedVideoIdSet = null;
      _resolvedCachePath = null;
    } catch (_) {}
  }

  void dispose() {
    // No-op: client managed by YoutubeClientService
  }
}

class _CachedUrl {
  final String url;
  final int timestamp;

  _CachedUrl({required this.url, required this.timestamp});

  bool get isExpired {
    if (_isUrlExpired(url)) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - timestamp >= 1000 * 60 * 60 * 5; // 5 hours
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
