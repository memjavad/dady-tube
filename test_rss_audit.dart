import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

void main() async {
  final ids = [
    'UCyJpY9gC19_29J00B66_hNA', // Current
    'UCXQ3-_m82KAnh-U6brMmvrA', // Found via search
    'UC_Hj0fL5H2J_g-zL3g0R_7w', // Old smurfs?
  ];

  print('--- RSS AUDIT ---');
  for (final id in ids) {
    print('\nChecking ID: $id...');
    try {
      final url = 'https://www.youtube.com/feeds/videos.xml?channel_id=$id';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final title = document.findAllElements('title').first.innerText;
        final entries = document.findAllElements('entry');
        print('Title: $title');
        print('Entries: ${entries.length}');
        if (entries.isNotEmpty) {
           print('First video: ${entries.first.findAllElements('title').first.innerText}');
        }
      } else {
        print('RSS Failed (Status ${response.statusCode})');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
