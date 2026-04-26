import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DownloadService {
  static const String _keyDownloaded = 'downloaded_video_ids';
  final yt.YoutubeExplode _yt;
  final http.Client _client;

  // Dependency injection constructor
  DownloadService({yt.YoutubeExplode? ytClient, http.Client? httpClient})
    : _yt = ytClient ?? yt.YoutubeExplode(),
      _client = httpClient ?? http.Client();

  // ⚡ Fix 1: Cache the resolved path — getApplicationDocumentsDirectory() only called once
  Future<String>? _resolvedLocalPathFuture;

  Future<String> get _localPath {
    _resolvedLocalPathFuture ??= getApplicationDocumentsDirectory().then((dir) => dir.path);
    return _resolvedLocalPathFuture!;
  }

  // Visible for testing
  String sanitizeVideoId(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
  }

  Future<File> _getLocalFile(String videoId) async {
    final path = await _localPath;
    final sanitizedId = sanitizeVideoId(videoId);
    return File('$path/$sanitizedId.mp4');
  }

  Future<void> downloadVideo(
    String videoId,
    Function(double) onProgress,
  ) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.muxed.withHighestBitrate();

      if (streamInfo == null) throw Exception("No downloadable stream found.");

      final url = streamInfo.url;
      final totalSize = streamInfo.size.totalBytes;
      final file = await _getLocalFile(videoId);

      if (await file.exists()) await file.delete();

      // Parallel Turbo: 4 concurrent connections
      const int segmentCount = 4;
      final int segmentSize = (totalSize / segmentCount).ceil();

      List<Future<void>> downloadTasks = [];
      int downloadedBytes = 0;

      // ⚡ Fix: Use a dedicated RandomAccessFile for each concurrent chunk download to avoid
      // 'An async operation is currently pending' during parallel write and setPosition operations.
      for (int i = 0; i < segmentCount; i++) {
        final start = i * segmentSize;
        final end = (i == segmentCount - 1)
            ? totalSize - 1
            : (i + 1) * segmentSize - 1;

        downloadTasks.add(() async {
          final raf = await file.open(mode: FileMode.append);
          try {
            final response = await _client
                .send(
                  http.Request('GET', url)
                    ..headers['Range'] = 'bytes=$start-$end',
                )
                .timeout(const Duration(seconds: 10));

            int currentPos = start;
            await for (final chunk in response.stream) {
              await raf.setPosition(currentPos);
              await raf.writeFrom(chunk);
              currentPos += chunk.length;

              downloadedBytes += chunk.length;
              onProgress(downloadedBytes / totalSize);
            }
          } catch (e) {
            debugPrint('Segment Download Error: $e');
          } finally {
            await raf.close();
          }
        }());
      }

      await Future.wait(downloadTasks);
      await _markAsDownloaded(videoId);
    } catch (e) {
      debugPrint('Parallel Download Error: $e');
      rethrow;
    }
  }

  Future<void> _markAsDownloaded(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final downloaded = prefs.getStringList(_keyDownloaded) ?? [];
    if (!downloaded.contains(videoId)) {
      downloaded.add(videoId);
      await prefs.setStringList(_keyDownloaded, downloaded);
    }
  }

  Future<bool> isDownloaded(String videoId) async {
    final file = await _getLocalFile(videoId);
    return await file.exists();
  }

  Future<String?> getLocalPath(String videoId) async {
    final file = await _getLocalFile(videoId);
    if (await file.exists()) return file.path;
    return null;
  }

  Future<void> deleteVideo(String videoId) async {
    final file = await _getLocalFile(videoId);
    if (await file.exists()) await file.delete();

    final prefs = await SharedPreferences.getInstance();
    final downloaded = prefs.getStringList(_keyDownloaded) ?? [];
    downloaded.remove(videoId);
    await prefs.setStringList(_keyDownloaded, downloaded);
  }

  void dispose() {
    _yt.close();
    _client.close();
  }
}
