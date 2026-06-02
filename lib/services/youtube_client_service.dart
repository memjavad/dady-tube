import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
// ignore: implementation_imports
import 'package:youtube_explode_dart/src/reverse_engineering/youtube_http_client.dart';

import 'dart:math';

/// A custom HTTP client that injects browser-like headers on every request.
/// This makes DadyTube's network traffic look indistinguishable from a real
/// Chrome browser session, significantly reducing YouTube bot-detection blocks.
class _BrowserHttpClient extends YoutubeHttpClient {
  String? _cookieString;
  String? _visitorId;
  int _uaIndex = 0;

  static const List<String> _userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15',
  ];

  _BrowserHttpClient({String? cookieString, String? visitorId}) 
    : _cookieString = cookieString,
      _visitorId = visitorId;

  void updateCookies(String? cookies) {
    _cookieString = cookies;
  }

  void updateVisitorId(String? visitorId) {
    _visitorId = visitorId;
  }

  /// Rotates the User-Agent index to the next one in the list.
  void rotateUserAgent() {
    _uaIndex = (_uaIndex + 1) % _userAgents.length;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // If request goes to InnerTube API, do not inject desktop browser headers.
    // That triggers signature/client verification mismatches (e.g. claiming to be TV client but carrying Chrome desktop UA).
    if (request.url.path.contains('/youtubei/')) {
      if (_cookieString != null && _cookieString!.isNotEmpty) {
        request.headers['Cookie'] = _cookieString!;
      }
      return super.send(request);
    }

    final ua = _userAgents[_uaIndex];
    
    // Inject realistic browser headers that YouTube expects from a human user
    request.headers.putIfAbsent('User-Agent', () => ua);
    request.headers.putIfAbsent('Accept-Language', () => 'en-US,en;q=0.9,ar;q=0.8');
    request.headers.putIfAbsent(
      'Accept',
      () => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    );
    request.headers.putIfAbsent('Origin', () => 'https://www.youtube.com');
    request.headers.putIfAbsent('Referer', () => 'https://www.youtube.com/');
    
    // Interactive headers for modern YouTube APIs
    request.headers.putIfAbsent('X-YouTube-Client-Name', () => '1');
    request.headers.putIfAbsent('X-YouTube-Client-Version', () => '2.20240503.00.00');
    
    if (_visitorId != null) {
      request.headers.putIfAbsent('X-Goog-Visitor-Id', () => _visitorId!);
    }
    
    // Advanced browser headers (Sec-Ch-Ua) for better mimicry
    if (ua.contains('Android')) {
      request.headers.putIfAbsent('sec-ch-ua-mobile', () => '?1');
      request.headers.putIfAbsent('sec-ch-ua-platform', () => '"Android"');
    } else if (ua.contains('iPhone')) {
      request.headers.putIfAbsent('sec-ch-ua-mobile', () => '?1');
      request.headers.putIfAbsent('sec-ch-ua-platform', () => '"iOS"');
    } else {
      request.headers.putIfAbsent('sec-ch-ua-mobile', () => '?0');
      request.headers.putIfAbsent('sec-ch-ua-platform', () => '"Windows"');
    }

    request.headers.putIfAbsent('sec-fetch-dest', () => 'document');
    request.headers.putIfAbsent('sec-fetch-mode', () => 'navigate');
    request.headers.putIfAbsent('sec-fetch-site', () => 'none');
    request.headers.putIfAbsent('sec-fetch-user', () => '?1');
    request.headers.putIfAbsent('upgrade-insecure-requests', () => '1');
    request.headers.putIfAbsent('service-worker-navigation-preload', () => 'true');

    // Inject parent-provided session cookies if available (authenticated requests
    // are almost never flagged by YouTube's bot detection).
    if (_cookieString != null && _cookieString!.isNotEmpty) {
      request.headers['Cookie'] = _cookieString!;
    }

    return super.send(request);
  }
}

/// Singleton service that manages a persistent YoutubeExplode client.
/// This minimizes overhead from repeated client initialization and DNS/TCP lookups.
/// Upgraded with browser-like headers and optional parent-provided cookie injection
/// to reduce YouTube bot-detection blocks.
class YoutubeClientService {
  static final YoutubeClientService _instance =
      YoutubeClientService._internal();
  factory YoutubeClientService() => _instance;

  static const String _keyCookies = 'yt_session_cookies';
  static const String _keyCookieTimestamp = 'yt_cookies_saved_at';
  static const String _keyVisitorId = 'yt_visitor_id';

  final _BrowserHttpClient _browserClient;
  late final yt.YoutubeExplode _client;
  late final Future<void> _initializationFuture;

  YoutubeClientService._internal()
    : _browserClient = _BrowserHttpClient() {
    _client = yt.YoutubeExplode(httpClient: _browserClient);
    _initializationFuture = _loadInitialState();
  }

  /// Gets the persistent YoutubeExplode client.
  yt.YoutubeExplode get client => _client;

  /// Gets a shared HTTP client for other low-level network operations
  /// to leverage the same connection pool and browser headers.
  http.Client get httpClient => _browserClient;

  /// Ensures persisted state and startup network state are loaded before use.
  Future<void> ensureReady() => _initializationFuture;

  /// Loads saved cookies and visitor identity.
  Future<void> _loadInitialState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Cookies
      final savedCookies = prefs.getString(_keyCookies);
      if (savedCookies != null && savedCookies.isNotEmpty) {
        _browserClient.updateCookies(savedCookies);
      }

      // Load or Create Visitor ID
      String? visitorId = prefs.getString(_keyVisitorId);
      if (visitorId == null || visitorId.isEmpty) {
        visitorId = _generateVisitorId();
        await prefs.setString(_keyVisitorId, visitorId);
      }
      _browserClient.updateVisitorId(visitorId);
    } catch (_) {}
  }

  /// Generates a randomized, persistent string to look like a unique YouTube visitor
  String _generateVisitorId() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
    final rand = Random();
    return List.generate(22, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Saves a parent-provided cookie string and immediately activates it.
  Future<void> saveCookies(String cookieString) async {
    await ensureReady();
    _browserClient.updateCookies(cookieString.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCookies, cookieString.trim());
    await prefs.setInt(
      _keyCookieTimestamp,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Returns the last time cookies were saved, or null if never saved.
  Future<DateTime?> getCookiesSavedAt() async {
    await ensureReady();
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_keyCookieTimestamp);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  /// Returns true if a cookie string has been set.
  Future<bool> hasCookies() async {
    await ensureReady();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyCookies);
    return saved != null && saved.isNotEmpty;
  }

  /// Clears saved cookies.
  Future<void> clearCookies() async {
    await ensureReady();
    _browserClient.updateCookies(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCookies);
    await prefs.remove(_keyCookieTimestamp);
  }

  /// Rotates the browser identity (User-Agent) and generates a fresh Visitor ID.
  /// Use this when a request fails due to bot detection to try a fresh fingerprint.
  Future<void> resetIdentity() async {
    await ensureReady();
    _browserClient.rotateUserAgent();
    
    final newVisitorId = _generateVisitorId();
    _browserClient.updateVisitorId(newVisitorId);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVisitorId, newVisitorId);
    
    debugPrint('🔄 Identity Reset: New UA and VisitorID ($newVisitorId) applied.');
  }

  /// Legacy method for rotating only UA
  void rotateUserAgent() {
    _browserClient.rotateUserAgent();
  }

  /// Closes resources. Should be called when the app is being disposed.
  void dispose() {
    _client.close();
    _browserClient.close();
  }
}
