import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/services/youtube_client_service.dart';

void main() {
  group('YoutubeClientService Test', () {
    test('returns same singleton instance', () {
      final instance1 = YoutubeClientService();
      final instance2 = YoutubeClientService();

      expect(identical(instance1, instance2), isTrue);
    });

    test('initializes client properties', () {
      final service = YoutubeClientService();

      expect(service.client, isNotNull);
      expect(service.httpClient, isNotNull);
    });

    test('dispose does not throw', () {
      final service = YoutubeClientService();

      expect(() => service.dispose(), returnsNormally);
    });
  });
}
