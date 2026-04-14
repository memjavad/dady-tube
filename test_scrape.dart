import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://www.youtube.com/@SpacetoonYouTube/videos?hl=ar&gl=IQ';
  print('Fetching: $url');

  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Accept-Language': 'ar-IQ,ar;q=0.9,en-US;q=0.8,en;q=0.7',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
    );

    if (response.statusCode == 200) {
      final body = response.body;
      print('Body length: ${body.length}');

      if (body.contains('ytInitialData = ')) {
        print('Found ytInitialData!');
        final parts = body.split('ytInitialData = ');
        final jsonStr = parts[1].split(';</script>')[0];
        print('JSON length: ${jsonStr.length}');

        final data = json.decode(jsonStr);
        // Navigate through the complex JSON structure to find videos
        // Usually: contents.twoColumnBrowseResultsRenderer.tabs[1].tabRenderer.content.richGridRenderer.contents
        print('Successfully parsed JSON.');

        // Let's try to find the first video title
        try {
          final videos =
              data['contents']['twoColumnBrowseResultsRenderer']['tabs'][1]['tabRenderer']['content']['richGridRenderer']['contents'];
          for (var i = 0; i < 3 && i < videos.length; i++) {
            final video =
                videos[i]['richItemRenderer']['content']['videoRenderer'];
            final title = video['title']['runs'][0]['text'];
            print('Video $i Title: $title');
          }
        } catch (e) {
          print('Error navigating JSON: $e');
        }
      } else {
        print('ytInitialData not found!');
      }
    } else {
      print('HTTP Status: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
