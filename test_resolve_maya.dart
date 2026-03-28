import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final handles = ['@MayatheBee-Arabic', '@madinat-alasdiqa'];

  print('--- DEEP RESOLVE ---');
  for (final handle in handles) {
    try {
      print('\nResolving $handle...');
      final channel = await yt.channels.getByHandle(handle);
      print('Name: ${channel.title}');
      print('ID: ${channel.id.value}');
      
      final videos = await yt.channels.getUploads(channel.id).take(5).toList();
      print('Found ${videos.length} videos.');
      for (final v in videos) {
        print(' - ${v.title}');
      }
    } catch (e) {
      print('Failed for $handle: $e');
      // Try search
      try {
        final search = await yt.search.searchContent(handle);
        for (final item in search) {
          if (item is SearchChannel) {
             print('Search Found Channel: ${item.name} | ID: ${item.id.value}');
             final videos = await yt.channels.getUploads(item.id).take(5).toList();
             print('Search Found ${videos.length} videos.');
             break;
          }
        }
      } catch (e2) {
        print('Search failed too: $e2');
      }
    }
  }
  yt.close();
}
