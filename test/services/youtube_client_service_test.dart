import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:dadytube/services/youtube_client_service.dart';

void main() {
  group('YoutubeClientService Test', () {
    test('dispose should close the clients', () async {
      final service = YoutubeClientService();

      expect(service.client, isNotNull);
      expect(service.httpClient, isNotNull);

      service.dispose();

      // When the client is closed, it throws a ClientException
      // containing "HTTP request failed. Client is already closed."
      // Let's verify it's specifically a ClientException due to closure

      try {
        await service.httpClient.get(Uri.parse('https://example.com'));
        fail('Should have thrown a ClientException');
      } on http.ClientException catch (e) {
        expect(e.message.contains('closed'), isTrue,
          reason: 'Exception should indicate client is closed, got: ${e.message}');
      }

      // YoutubeExplode wraps the inner HttpClientClosedException inside a Retry logic
      // which eventually might bubble up as HttpClientClosedException or YoutubeExplodeException
      // But we can check specifically if it throws when closed.
      // Based on our previous trace, it throws HttpClientClosedException which isn't exported directly,
      // so we will match by type string.
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
