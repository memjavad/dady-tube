import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Singleton service that manages a persistent YoutubeExplode client.
/// This minimizes overhead from repeated client initialization and DNS/TCP lookups.
class YoutubeClientService {
  static final YoutubeClientService _instance =
      YoutubeClientService._internal();
  factory YoutubeClientService() => _instance;

  yt.YoutubeExplode _client;
  final http.Client _httpClient;

  YoutubeClientService._internal()
    : _httpClient = http.Client(),
      _client = yt.YoutubeExplode();

  /// Gets the persistent YoutubeExplode client.
  yt.YoutubeExplode get client => _client;

  /// Gets a shared HTTP client for other low-level network operations
  /// to leverage the same connection pool.
  http.Client get httpClient => _httpClient;

  @visibleForTesting
  void setMockClient(yt.YoutubeExplode mockClient) {
    _client = mockClient;
  }

  /// Closes resources. Should be called when the app is being disposed.
  void dispose() {
    _client.close();
    _httpClient.close();
  }
}
