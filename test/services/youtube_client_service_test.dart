import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:http/http.dart' as http;
import 'package:dadytube/services/youtube_client_service.dart';

void main() {
  group('YoutubeClientService', () {
    test('returns the same instance (singleton)', () {
      final instance1 = YoutubeClientService();
      final instance2 = YoutubeClientService();

      expect(identical(instance1, instance2), isTrue);
    });

    test('initializes and returns YoutubeExplode client', () {
      final service = YoutubeClientService();
      expect(service.client, isA<yt.YoutubeExplode>());
    });

    test('initializes and returns http.Client', () {
      final service = YoutubeClientService();
      expect(service.httpClient, isA<http.Client>());
    });

    test('dispose should close the clients', () async {
      final service = YoutubeClientService();

      expect(service.client, isNotNull);
      expect(service.httpClient, isNotNull);

      service.dispose();

      // When the client is closed, it throws a ClientException
      // containing "HTTP request failed. Client is already closed."
      try {
        await service.httpClient.get(Uri.parse('https://example.com'));
        fail('Should have thrown a ClientException');
      } on http.ClientException catch (e) {
        expect(e.message.contains('closed'), isTrue,
          reason: 'Exception should indicate client is closed, got: ${e.message}');
      }

      // YoutubeExplode wraps the inner HttpClientClosedException inside a Retry logic
      // which eventually might bubble up as HttpClientClosedException or YoutubeExplodeException
      try {
        await service.client.videos.get('12345678901');
        fail('Should have thrown an exception due to closed client');
      } catch (e) {
        expect(e.runtimeType.toString(), contains('HttpClientClosedException'),
          reason: 'Exception should indicate http client is closed, got: ${e.runtimeType.toString()}');
      }
    });
  });
}
