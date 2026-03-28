import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/youtube_service.dart';

class DownloadProvider extends ChangeNotifier {
  static const String _keyMetadata = 'downloaded_metadata';
  Map<String, YoutubeVideo> _downloadedMetadata = {};

  DownloadProvider() {
    _loadMetadata();
  }

  List<YoutubeVideo> get downloadedVideos => _downloadedMetadata.values.toList();

  Future<void> _loadMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final metadataJson = prefs.getString(_keyMetadata);
    if (metadataJson != null) {
      final Map<String, dynamic> decoded = json.decode(metadataJson);
      _downloadedMetadata = decoded.map((key, value) => 
          MapEntry(key, YoutubeVideo.fromJson(value)));
    }
    notifyListeners();
  }

  Future<void> addDownloadedVideo(YoutubeVideo video) async {
    _downloadedMetadata[video.id] = video;
    await _saveMetadata();
    notifyListeners();
  }

  Future<void> removeDownloadedVideo(String videoId) async {
    _downloadedMetadata.remove(videoId);
    await _saveMetadata();
    notifyListeners();
  }

  Future<void> _saveMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_downloadedMetadata.map((key, value) => 
        MapEntry(key, value.toJson())));
    await prefs.setString(_keyMetadata, encoded);
  }
}
