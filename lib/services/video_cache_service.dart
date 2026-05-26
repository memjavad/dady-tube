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

  @visibleForTesting
  yt.YoutubeExplode? mockYt;
  @visibleForTesting
  http.Client? mockHttpClient;

  yt.YoutubeExplode get _yt => mockYt ?? YoutubeClientService().client;
  final Map<String, _PersistentManifest> _manifestCache = {};
  final Map<String, Future<yt.StreamManifest>> _activeFetches = {};
  static const int _maxCacheEntries = 25;
  static const int _manifestTTLHours = 5;

  String? _resolvedCachePath;
  Future<String>? _resolvingCachePathFuture;

  Future<String> get _cachePath async {
    if (_resolvedCachePath != null) return _resolvedCachePath!;
    if (_resolvingCachePathFuture != null)
      return await _resolvingCachePathFuture!;

    _resolvingCachePathFuture = getTemporaryDirectory().then((directory) {
      _resolvedCachePath = '${directory.path}/video_cache';
      return _resolvedCachePath!;
    });

    return await _resolvingCachePathFuture!;
  }

  final Map<String, _CachedUrl> _streamUrlMemCache = {};

  String _sanitizeId(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  String sanitizeVideoId(String id) => _sanitizeId(id);

  Future<void> _persistStreamUrl(String videoId, String url) async {
    try {
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

  Future<String?> getCachedStreamUrl(String videoId) async {
    final mem = _streamUrlMemCache[videoId];
    if (mem != null && !mem.isExpired) return mem.url;

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
        _streamUrlMemCache[videoId] = _CachedUrl(
          url: url,
          timestamp: timestamp,
        );
        return url;
      }
    } catch (_) {}
    return null;
  }

  Future<void> invalidateVideoSession(String videoId) async {
    _manifestCache.remove(videoId);
    _activeFetches.remove(videoId);
    _streamUrlMemCache.remove(videoId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('persistent_stream_urls');
      if (jsonStr == null) return;

      final Map<String, dynamic> data = json.decode(jsonStr);
      if (data.remove(videoId) != null) {
        await prefs.setString('persistent_stream_urls', json.encode(data));
      }
    } catch (_) {}
  }

  static final _ytClients = [
    yt.YoutubeApiClient.tv,
    yt.YoutubeApiClient.androidVr,
    yt.YoutubeApiClient.ios,
    yt.YoutubeApiClient.android,
    yt.YoutubeApiClient.safari,
  ];

  final Set<yt.YoutubeApiClient> _failedClients = {};

  Future<yt.StreamManifest> getManifest(String videoId) async {
    return getManifestWithOptions(videoId);
  }

  Future<yt.StreamManifest> getManifestWithOptions(
    String videoId, {
    bool forceRefresh = false,
  }) async {
    await YoutubeClientService().ensureReady();
    if (forceRefresh) {
      await invalidateVideoSession(videoId);
    }

    if (_manifestCache.containsKey(videoId)) {
      final cached = _manifestCache[videoId]!;
      if (!cached.isExpired) return cached.manifest;
    }

    if (_activeFetches.containsKey(videoId)) {
      return await _activeFetches[videoId]!;
    }

    final fetchFuture = _fetchManifestWithRetry(videoId);
    _activeFetches[videoId] = fetchFuture;

    try {
      final manifest = await fetchFuture;
      _manifestCache[videoId] = _PersistentManifest(
        manifest: manifest,
        timestamp: DateTime.now(),
      );

      final bestStream = manifest.muxed.withHighestBitrate();
      _persistStreamUrl(videoId, bestStream.url.toString());

      return manifest;
    } on yt.VideoUnplayableException catch (e) {
      debugPrint('🚫 Video Unplayable (all clients exhausted): $videoId - $e');
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Manifest Fetch Error: $videoId - $e');
      rethrow;
    } finally {
      _activeFetches.remove(videoId);
    }
  }

  /// Clears the record of failed clients, allowing all clients to be tried again.
  /// Call this after rotating the global identity in YoutubeClientService.
  void clearFailedClients() {
    _failedClients.clear();
    debugPrint('♻️ Failed clients list cleared for retry.');
  }

  Future<yt.StreamManifest> _fetchManifestWithRetry(String videoId) async {
    Object? lastError;
    const delays = [0, 1, 2];

    for (int attempt = 0; attempt < _ytClients.length; attempt++) {
      // Re-evaluate ordered list on each attempt in case _failedClients changed
      final orderedClients = [
        ..._ytClients.where((c) => !_failedClients.contains(c)),
        ..._ytClients.where((c) => _failedClients.contains(c)),
      ];

      final client = orderedClients[attempt];
      final delayIndex = attempt < delays.length ? attempt : delays.length - 1;

      if (delays[delayIndex] > 0) {
        await Future.delayed(Duration(seconds: delays[delayIndex]));
      }

      try {
        debugPrint(
          '🎬 Manifest attempt ${attempt + 1}/${orderedClients.length} '
          'for $videoId using client: $client',
        );
        final manifest = await _yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: [client],
        );

        _failedClients.remove(client);
        return manifest;
      } on yt.VideoUnplayableException catch (e) {
        final msg = e.toString().toLowerCase();
        final isBot =
            msg.contains('bot') ||
            msg.contains('sign in') ||
            msg.contains('confirm') ||
            msg.contains('robot') ||
            msg.contains('available'); // "Not available" is often a soft-block

        if (isBot) {
          debugPrint('🤖 Bot-block on client $client, marking as failed...');
          _failedClients.add(client);
          lastError = e;
          continue;
        }
        rethrow;
      } catch (e) {
        debugPrint('⚠️ Client $client failed: $e');
        lastError = e;
        continue;
      }
    }

    if (lastError != null) throw lastError;
    throw yt.VideoUnplayableException.unplayable(
      yt.VideoId(videoId),
      reason: 'All clients exhausted',
    );
  }

  bool _isBackgroundPaused = false;
  bool get isBackgroundPaused => _isBackgroundPaused;
  bool _playbackFocus = false;
  final Set<http.Client> _activeClients = {};

  /// Toggles global playback focus. When true, all background fetches are strictly
  /// suppressed and cannot be resumed until focus is released.
  void setPlaybackFocus(bool active) {
    _playbackFocus = active;
    if (active) {
      pauseBackgroundOperations();
    } else {
      resumeBackgroundOperations();
    }
  }

  void pauseBackgroundOperations() {
    _isBackgroundPaused = true;
    for (var client in _activeClients) {
      try {
        client.close();
      } catch (_) {}
    }
    _activeClients.clear();
  }

  void resumeBackgroundOperations() {
    if (!_isBackgroundPaused) return;
    if (_playbackFocus) {
      debugPrint(
        '⏸️ VideoCacheService: Resume suppressed while Playback Focus is active.',
      );
      return;
    }
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
      await YoutubeClientService().ensureReady();
      final cachedUrl = await getCachedStreamUrl(videoId);
      if (cachedUrl == null) {
        final manifest = await getManifest(videoId);
        try {
          final bestStream = manifest.muxed.withHighestBitrate();
          final warmUrl = bestStream.url;
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

  Future<String?> getCachedVideoPath(String videoId) async {
    return _getExistingFilePath(videoId, '.mp4');
  }

  Set<String>? _cachedVideoIdSet;

  @visibleForTesting
  void invalidateCachedIdSetForTest() => _invalidateCachedIdSet();

  void _invalidateCachedIdSet() => _cachedVideoIdSet = null;

  Future<Set<String>> getCachedVideoIds() async {
    if (_cachedVideoIdSet != null) return _cachedVideoIdSet!;

    final path = await _cachePath;
    final dir = Directory(path);
    if (!(await dir.exists())) {
      _cachedVideoIdSet = {};
      return _cachedVideoIdSet!;
    }

    final List<String> paths = [];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.mp4')) {
        paths.add(entity.path);
      }
    }

    // ⚡ Bolt: Accumulating paths quickly in the await for loop and deferring string manipulation prevents stream delays.
    // Additionally, substring and lastIndexOf are faster than split and replaceAll.
    final Set<String> ids = {};
    for (final path in paths) {
      final slashIndex = path.lastIndexOf(Platform.pathSeparator);
      final name = slashIndex != -1 ? path.substring(slashIndex + 1) : path;
      ids.add(name.substring(0, name.length - 4));
    }
    _cachedVideoIdSet = ids;
    return _cachedVideoIdSet!;
  }

  Future<void> cacheVideo(
    String videoId, {
    String title = '',
    String thumbnailUrl = '',
    String channelId = '',
  }) async {
    await _waitUntilResumed();
    final existing = await getCachedVideoPath(videoId);
    if (existing != null) return;

    final client = mockHttpClient ?? http.Client();
    _activeClients.add(client);
    File? file;
    try {
      final manifest = await getManifest(videoId);
      final streamInfo = manifest.muxed.withHighestBitrate();

      final url = streamInfo.url;
      final totalSize = streamInfo.size.totalBytes;
      final cacheDir = await _cachePath;
      await Directory(cacheDir).create(recursive: true);

      final sanitizedId = _sanitizeId(videoId);
      file = File('$cacheDir/$sanitizedId.mp4');

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
              if (_isBackgroundPaused) break;
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
        return;
      }

      final sink = file.openWrite();
      try {
        for (int i = 0; i < segmentCount; i++) {
          final partFile = File('${file.path}.part$i');
          if (await partFile.exists()) {
            final stream = partFile.openRead();
            await sink.addStream(stream);
            await partFile.delete();
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      _cachedVideoIdSet?.add(sanitizedId);

      if (title.isNotEmpty) {
        await writeMetaSidecarForTest(
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

  Future<void> cachePreview(String videoId) async {
    await YoutubeClientService().ensureReady();
    if (await getCachedVideoPath(videoId) != null) return;

    final cacheDir = await _cachePath;
    final sanitizedId = _sanitizeId(videoId);
    final previewFile = File('$cacheDir/$sanitizedId.preview');
    if (await previewFile.exists()) return;

    try {
      final manifest = await getManifest(videoId);
      final streamInfo = manifest.muxed.withHighestBitrate();

      await Directory(cacheDir).create(recursive: true);

      final stream = _yt.videos.streamsClient.get(streamInfo);
      final ios = previewFile.openWrite();

      int totalBytes = 0;
      const int maxBytes = 1524 * 1024;

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

  Future<String?> getPreviewPath(String videoId) async {
    return _getExistingFilePath(videoId, '.preview');
  }

  Future<void> _manageCacheSize() async {
    final path = await _cachePath;
    final dir = Directory(path);
    if (!(await dir.exists())) return;

    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.mp4')) {
        files.add(entity);
      }
    }
    if (files.length <= _maxCacheEntries) return;

    final filesWithStats = files
        .map((f) => (file: f, modified: f.lastModifiedSync()))
        .toList();
    filesWithStats.sort((a, b) => a.modified.compareTo(b.modified));

    final sortedFiles = filesWithStats.map((e) => e.file).toList();

    final deleteTasks = <Future<void>>[];
    for (int i = 0; i < sortedFiles.length - _maxCacheEntries; i++) {
      deleteTasks.add(() async {
        try {
          await sortedFiles[i].delete();
          final base = sortedFiles[i].path.replaceAll('.mp4', '');
          final metaFile = File('$base.meta');
          if (await metaFile.exists()) await metaFile.delete();
          final previewFile = File('$base.preview');
          if (await previewFile.exists()) await previewFile.delete();

          final name = sortedFiles[i].path
              .split(Platform.pathSeparator)
              .last
              .replaceAll('.mp4', '');
          _cachedVideoIdSet?.remove(name);
        } catch (_) {}
      }());
    }
    if (deleteTasks.isNotEmpty) {
      await Future.wait(deleteTasks);
    }
  }

  static const String _keyLastCacheDate = 'last_auto_cache_date';
  static const String _keyDailyCacheCount = 'daily_auto_cache_count';
  static const String _keyLastCacheTimestamp = 'last_auto_cache_timestamp';
  static const int _maxDailyCache = 1;

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

    final isNightTime = now.hour >= 23 || now.hour < 5;

    bool shouldProceed = false;
    if (isNightTime) {
      shouldProceed = (timeSinceLastCache > 1000 * 60 * 60 * 2);
    } else {
      shouldProceed = (timeSinceLastCache > 1000 * 60 * 60 * 12);
    }

    if (!ignoreTimers && !deep && !shouldProceed && lastTimestamp != 0) {
      debugPrint(
        'Smart Cache: Too soon to cache again. (Last cache: ${DateTime.fromMillisecondsSinceEpoch(lastTimestamp)})',
      );
      return;
    }

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

    final manifestLimit = deep ? 100 : 2;
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

  @visibleForTesting
  Future<void> writeMetaSidecarForTest(
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
      _streamUrlMemCache.clear();
      _manifestCache.clear();
      _cachedVideoIdSet = null;
      _resolvedCachePath = null;
      _resolvingCachePathFuture = null;
    } catch (_) {}
  }

  void dispose() {}
}

class _CachedUrl {
  final String url;
  final int timestamp;

  _CachedUrl({required this.url, required this.timestamp});

  bool get isExpired {
    if (_isUrlExpired(url)) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - timestamp >= 1000 * 60 * 60 * 5;
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
