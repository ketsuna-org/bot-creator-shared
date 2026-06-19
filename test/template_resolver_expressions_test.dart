import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('resolveTemplateExpressionValue', () {
    test('normalizes string casing and whitespace', () {
      expect(
        resolveTemplateExpressionValue(
          'lowercase("HeLLo")',
          <String, String>{},
        ),
        'hello',
      );
      expect(
        resolveTemplateExpressionValue(
          'uppercase("HeLLo")',
          <String, String>{},
        ),
        'HELLO',
      );
      expect(
        resolveTemplateExpressionValue(
          'trim("  spaced  ")',
          <String, String>{},
        ),
        'spaced',
      );
    });

    test('supports replace and contains helpers', () {
      expect(
        resolveTemplateExpressionValue(
          'replace("Hello there", "there", "world")',
          <String, String>{},
        ),
        'Hello world',
      );

      expect(
        resolveTemplatePlaceholders('((contains("AbCd", "bc")))', {}),
        'true',
      );
      expect(resolveTemplatePlaceholders('((contains("AbCd", "zz")))', {}), '');
    });

    test('supports BDScript-like casing aliases and title case', () {
      expect(
        resolveTemplateExpressionValue(
          'toLowerCase("HeLLo")',
          <String, String>{},
        ),
        'hello',
      );
      expect(
        resolveTemplateExpressionValue(
          'toUpperCase("HeLLo")',
          <String, String>{},
        ),
        'HELLO',
      );
      expect(
        resolveTemplateExpressionValue(
          'toTitleCase("hello world_from bot")',
          <String, String>{},
        ),
        'Hello World_From Bot',
      );
    });

    test('supports charCount and linesCount helpers', () {
      expect(
        resolveTemplateExpressionValue('charCount("abc")', <String, String>{}),
        3,
      );
      expect(
        resolveTemplateExpressionValue(
          'linesCount("a\\nb\\nc")',
          <String, String>{},
        ),
        3,
      );
      expect(
        resolveTemplateExpressionValue('linesCount("")', <String, String>{}),
        0,
      );
    });

    test('supports numberSeparator helper', () {
      expect(
        resolveTemplateExpressionValue(
          'numberSeparator(1234567)',
          <String, String>{},
        ),
        '1,234,567',
      );
      expect(
        resolveTemplateExpressionValue(
          'numberSeparator(1234567, " ")',
          <String, String>{},
        ),
        '1 234 567',
      );
    });

    test('supports split helper with and without index', () {
      expect(
        resolveTemplateExpressionValue(
          'split("a,b,c", ",")',
          <String, String>{},
        ),
        <String>['a', 'b', 'c'],
      );
      expect(
        resolveTemplateExpressionValue(
          'split("a,b,c", ",", 1)',
          <String, String>{},
        ),
        'b',
      );
      expect(
        resolveTemplatePlaceholders('((split("a,b,c", ",")))', {}),
        '["a","b","c"]',
      );
      // Semicolon delimiter support
      expect(
        resolveTemplateExpressionValue(
          'split("a;b;c"; ";"; 1)',
          <String, String>{},
        ),
        'b',
      );
      expect(
        resolveTemplateExpressionValue(
          'split["a;b;c"; ";"; 1]',
          <String, String>{},
        ),
        'b',
      );
      expect(
        resolveTemplatePlaceholders('((split["a;b;c"; ";"; 1]))', {}),
        'b',
      );
    });

    test('supports cropText helper', () {
      expect(
        resolveTemplateExpressionValue(
          'cropText("hello world", 5)',
          <String, String>{},
        ),
        'hello...',
      );
      expect(
        resolveTemplateExpressionValue(
          'cropText("hello world", 5, "~")',
          <String, String>{},
        ),
        'hello~',
      );
      // Semicolon delimiter support
      expect(
        resolveTemplateExpressionValue(
          'cropText("hello world"; 5; "~")',
          <String, String>{},
        ),
        'hello~',
      );
      expect(
        resolveTemplateExpressionValue(
          'cropText("hello", 10)',
          <String, String>{},
        ),
        'hello',
      );
    });

    test('supports first, last and sum for arrays', () {
      expect(
        resolveTemplateExpressionValue('first(scores.\$)', <String, String>{
          'scores': '[3,5,8]',
        }),
        3,
      );

      expect(
        resolveTemplateExpressionValue('last(scores.\$)', <String, String>{
          'scores': '[3,5,8]',
        }),
        8,
      );

      expect(
        resolveTemplateExpressionValue('sum(scores.\$)', <String, String>{
          'scores': '[3,"5",null,"x",8.5]',
        }),
        16.5,
      );
    });

    test('supports length and at helpers for arrays', () {
      expect(
        resolveTemplateExpressionValue('length(scores.\$)', <String, String>{
          'scores': '[3,5,8]',
        }),
        3,
      );

      expect(
        resolveTemplateExpressionValue('at(scores.\$, 1)', <String, String>{
          'scores': '[3,5,8]',
        }),
        5,
      );
    });

    test('builds embed field payloads from object arrays', () {
      final resolved = resolveTemplateExpressionValue(
        'embedFields(scores.\$, "{name}", "{score}", true)',
        <String, String>{
          'scores': '[{"name":"Alice","score":7},{"name":"Bob","score":12}]',
        },
      );

      expect(resolved, <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Alice', 'value': '7', 'inline': true},
        <String, dynamic>{'name': 'Bob', 'value': '12', 'inline': true},
      ]);
    });

    test('rewrites avatar URL format and size', () {
      final resolved = resolveTemplateExpressionValue(
        'avatar(userAvatar, "png", 256)',
        <String, String>{
          'userAvatar':
              'https://cdn.discordapp.com/avatars/1/abc.webp?size=1024',
        },
      );

      expect(resolved, 'https://cdn.discordapp.com/avatars/1/abc.png?size=256');
    });

    test('rewrites banner URL with default values when args are missing', () {
      final resolved = resolveTemplateExpressionValue(
        'banner(userBanner)',
        <String, String>{
          'userBanner': 'https://cdn.discordapp.com/banners/1/def.png?size=512',
        },
      );

      expect(
        resolved,
        'https://cdn.discordapp.com/banners/1/def.webp?size=1024',
      );
    });
  });
}
