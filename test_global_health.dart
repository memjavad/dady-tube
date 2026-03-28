import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

void main() async {
  final channels = {
    'UCAfwGn6Xq-TscvdChnPrktQ': 'The Fixies بالعربية',
    'UCuQKih3Ac3NABADQKQdeV6A': 'Spacetoon',
    'UCOGBA-T3jCfOPey73FzsxCw': 'Nick Jr. Arabia',
    'UCNbmKQcBE3Sdx2HN6KGkxKw': 'Hello Maestro',
    'UCXGCkE7vRMkwQwLVHJPd8fQ': 'Octonauts',
    'UCXQ3-_m82KAnh-U6brMmvrA': 'Maya the Bee (NEW)',
    'UCBZLg-ixSGqEjh3ld7nSwLg': 'The Smurfs',
    'UC1ShKv0O7polu_tlhcqg4Xw': 'Sheriff Labrador',
    'UCvr9YT7AwMTxKDqou3e_OUQ': 'Zad Al-Horof',
    'UCT21_ci7c9PKYy9XZDHuJZg': 'Gecko\'s Garage',
    'UCqiIbqnJB0AVTg6Z6QnZNdw': 'Mansour',
    'UCpzp1_jpI3lfYy6eTW1kqhw': 'Friends City',
  };

  print('--- GLOBAL HEALTH CHECK ---');
  for (final entry in channels.entries) {
    final id = entry.key;
    final name = entry.value;
    try {
      final url = 'https://www.youtube.com/feeds/videos.xml?channel_id=$id';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final entries = document.findAllElements('entry');
        print('[OK] $name ($id) - ${entries.length} videos');
      } else {
        print('[FAIL] $name ($id) - Status ${response.statusCode}');
      }
    } catch (e) {
      print('[ERROR] $name ($id) - $e');
    }
  }
}
