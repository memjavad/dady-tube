import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/services/youtube_client_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:http/http.dart' as http;

void main() {
  group('YoutubeClientService', () {
    test(
      'should return the exact same instance on multiple instantiations',
      () {
        final instance1 = YoutubeClientService();
        final instance2 = YoutubeClientService();

        expect(instance1, same(instance2));
      },
    );

    test('should provide access to clients', () {
      final instance = YoutubeClientService();

      expect(instance.client, isA<yt.YoutubeExplode>());
      expect(instance.httpClient, isA<http.Client>());
    });

    test('dispose should not throw exceptions', () {
      final instance = YoutubeClientService();

      expect(() => instance.dispose(), returnsNormally);
    });
  });
}
