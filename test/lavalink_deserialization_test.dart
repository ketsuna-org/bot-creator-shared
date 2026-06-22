import 'package:nyxx_lavalink/nyxx_lavalink.dart';
import 'package:test/test.dart';

void main() {
  test('lavalink deserialization error test', () {
    final trackJson = <String, dynamic>{
      'encoded': 'encoded_string',
      'info': <String, dynamic>{
        'identifier': 'identifier_string',
        'isSeekable': true,
        'author': 'author_string',
        'length': 1000,
        'isStream': false,
        'position': 0,
        'title': 'title_string',
        'uri': 'https://example.com',
        'artworkUrl': 'https://example.com',
        'isrc': null,
        'sourceName': 'youtube',
      },
      'pluginInfo': <String, dynamic>{},
      'userData': null,
    };
    final track = Track.fromJson(trackJson);
    print('Deserialized successfully: ${track.info.title}');
  });
}
