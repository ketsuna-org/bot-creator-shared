import 'package:bot_creator_shared/utils/embed_fields.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('buildResolvedEmbedFields', () {
    test('merges static and dynamic fields while ignoring invalid entries', () {
      final runtimeVariables = <String, String>{
        'scores':
            '[{"name":"Alice","score":9},{"name":"Bob","score":12},{"name":"","score":5}]',
      };

      final fields = buildResolvedEmbedFields(
        embedJson: <String, dynamic>{
          'fields': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Static',
              'value': 'Always here',
              'inline': false,
            },
          ],
          'fieldsTemplate':
              '((embedFields(scores.\$, "{name}", "{score}", true)))',
        },
        resolve:
            (input) => resolveTemplatePlaceholders(input, runtimeVariables),
      );

      expect(fields.length, 3);
      expect(fields.first.name, 'Static');
      expect(fields[1].name, 'Alice');
      expect(fields[1].value, '9');
      expect(fields[1].isInline, isTrue);
      expect(fields[2].name, 'Bob');
    });

    test('keeps static fields when fieldsTemplate is malformed', () {
      final fields = buildResolvedEmbedFields(
        embedJson: <String, dynamic>{
          'fields': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Only',
              'value': 'Static',
              'inline': false,
            },
          ],
          'fieldsTemplate': '((embedFields(badJson.\$, "{name}", "{value}")))',
        },
        resolve:
            (input) => resolveTemplatePlaceholders(input, <String, String>{
              'badJson': '{not valid json}',
            }),
      );

      expect(fields.length, 1);
      expect(fields.single.name, 'Only');
      expect(fields.single.value, 'Static');
    });
  });
}
