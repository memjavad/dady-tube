import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/services/download_service.dart';
import 'package:dadytube/services/video_cache_service.dart';

void main() {
  group('Sanitization tests', () {
    test('DownloadService sanitizes path traversal correctly', () {
      final service = DownloadService();

      expect(service.sanitizeVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(service.sanitizeVideoId('../../../etc/passwd'), 'etcpasswd');
      expect(service.sanitizeVideoId('some_video-ID'), 'some_video-ID');
      expect(service.sanitizeVideoId('video?id=123&foo=bar'), 'videoid123foobar');
      expect(service.sanitizeVideoId('..\\..\\Windows\\System32'), 'WindowsSystem32');
      expect(service.sanitizeVideoId('/absolute/path/video'), 'absolutepathvideo');
    });

    test('VideoCacheService sanitizes path traversal correctly', () {
      final service = VideoCacheService();

      expect(service.sanitizeVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(service.sanitizeVideoId('../../../etc/passwd'), 'etcpasswd');
      expect(service.sanitizeVideoId('some_video-ID'), 'some_video-ID');
      expect(service.sanitizeVideoId('video?id=123&foo=bar'), 'videoid123foobar');
      expect(service.sanitizeVideoId('..\\..\\Windows\\System32'), 'WindowsSystem32');
      expect(service.sanitizeVideoId('/absolute/path/video'), 'absolutepathvideo');
    });
  });
}
