import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  try {
    final channelId = 'UCk0S2W_O86C9TsvH8L278fA'; // Spacetoon
    print('Fetching channel info for: $channelId');
    
    final channel = await yt.channels.get(channelId);
    print('Channel Title: ${channel.title}');
    
    print('Fetching uploads...');
    final videos = await yt.channels.getUploads(channelId).take(10).toList();
    
    if (videos.isEmpty) {
      print('No videos found.');
    } else {
      for (var video in videos) {
        print(' - Title: ${video.title}');
        print('   - ID: ${video.id}');
      }
    }
  } catch (e) {
    print('Error caught: $e');
  } finally {
    yt.close();
    print('Done.');
  }
}
