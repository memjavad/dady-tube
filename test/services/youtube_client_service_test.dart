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

    test('dispose executes without throwing', () {
      final service = YoutubeClientService();
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
