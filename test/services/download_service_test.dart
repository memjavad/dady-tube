import 'dart:io';
import 'dart:collection';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:dadytube/services/download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockYoutubeExplode extends Mock implements YoutubeExplode {}
class MockVideoClient extends Mock implements VideoClient {}
class MockStreamClient extends Mock implements StreamClient {}
class MockStreamManifest extends Mock implements StreamManifest {}
class MockMuxedStreamInfo extends Mock implements MuxedStreamInfo {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    // Mock path_provider
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });

    registerFallbackValue(http.Request('GET', Uri.parse('http://example.com')));
  });

  tearDownAll(() {
    final file = File('./jNQXAC9IVRw.mp4');
    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  test('downloadVideo handles HTTP exceptions and rethrows', () async {
    final client = MockHttpClient();
    final ytClient = MockYoutubeExplode();
    final videoClient = MockVideoClient();
    final streamClient = MockStreamClient();
    final streamManifest = MockStreamManifest();
    final muxedInfo = MockMuxedStreamInfo();

    // Mock the nested YT Explode structure
    when(() => ytClient.videos).thenReturn(videoClient);
    when(() => videoClient.streamsClient).thenReturn(streamClient);
    when(() => streamClient.getManifest(any())).thenAnswer((_) async => streamManifest);

    // Create a mock stream info object
    when(() => streamManifest.muxed).thenReturn(UnmodifiableListView<MuxedStreamInfo>([muxedInfo]));

    // Need a fake URL and Size
    when(() => muxedInfo.url).thenReturn(Uri.parse('http://example.com/video.mp4'));
    when(() => muxedInfo.size).thenReturn(FileSize(1000000));

    final service = DownloadService();
    service.setHttpClient(client);
    service.setYoutubeExplode(ytClient);

    // Mock client to throw an exception
    when(() => client.send(any())).thenThrow(Exception('Simulated network error'));

    // Try downloading - we expect it to fail early
    try {
      await service.downloadVideo('jNQXAC9IVRw', (progress) {});
      fail('Should have thrown an exception');
    } catch (e) {
      expect(e.toString(), contains('Simulated network error'));
    }
  });
}
