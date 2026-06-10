import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('resolveTemplatePlaceholders', () {
    test('resolves bot.ping placeholder', () {
      final resolved = resolveTemplatePlaceholders('Ping: ((bot.ping)) ms', {
        'bot.ping': '65',
      });

      expect(resolved, 'Ping: 65 ms');
    });

    test(
      'resolves direct keys case-insensitively with exact-match priority',
      () {
        final resolved = resolveTemplatePlaceholders('Hello ((UserName))', {
          'UserName': 'Jeremy',
          'username': 'Fallback',
        });

        expect(resolved, 'Hello Jeremy');
      },
    );

    test(
      'resolves JSON-path placeholders with case-insensitive source lookup',
      () {
        final resolved = resolveTemplatePlaceholders(
          r'Count: ((MyHttp.Body.$.items[0].count))',
          <String, String>{'myHttp.body': '{"items":[{"count":3}]}'},
        );

        expect(resolved, 'Count: 3');
      },
    );

    test(
      'keeps fallback at top level without splitting function arguments',
      () {
        final resolved = resolveTemplatePlaceholders(
          'Players: ((join(scores.\$, "|")|fallback))',
          <String, String>{'scores': '["Alice","Bob"]', 'fallback': 'nobody'},
        );

        expect(resolved, 'Players: Alice|Bob');
      },
    );

    test('falls back when the first resolved value is an empty string', () {
      final resolved = resolveTemplatePlaceholders(
        'Prefix: ((user.bc_prefix | guild.bc_prefix))',
        <String, String>{'user.bc_prefix': '', 'guild.bc_prefix': '!'},
      );

      expect(resolved, 'Prefix: !');
    });

    test('supports bare punctuation literal fallback values', () {
      final resolved = resolveTemplatePlaceholders(
        'Prefix: ((user.bc_prefix | guild.bc_prefix | !))',
        <String, String>{'user.bc_prefix': '', 'guild.bc_prefix': ''},
      );

      expect(resolved, 'Prefix: !');
    });

    test('resolves nested placeholders inside variable keys', () {
      final resolved = resolveTemplatePlaceholders(
        'Perms: ((permissions.byId.((author.id))|member.permissions))',
        <String, String>{
          'author.id': '243117191774470146',
          'permissions.byId.243117191774470146': 'manageguild,banmembers',
          'member.permissions': 'fallback',
        },
      );

      expect(resolved, 'Perms: manageguild,banmembers');
    });

    test(
      'falls back after nested key resolution when dynamic key is missing',
      () {
        final resolved = resolveTemplatePlaceholders(
          'Perms: ((permissions.byId.((author.id))|member.permissions))',
          <String, String>{
            'author.id': '243117191774470146',
            'member.permissions': 'manageguild',
          },
        );

        expect(resolved, 'Perms: manageguild');
      },
    );

    test('serializes slice results back to JSON text', () {
      final resolved = resolveTemplatePlaceholders(
        'Slice: ((slice(scores.\$, 1, 3)))',
        <String, String>{'scores': '["A","B","C","D"]'},
      );

      expect(resolved, 'Slice: ["B","C"]');
    });

    test('formats array items with nested object placeholders', () {
      final resolved = resolveTemplatePlaceholders(
        'Rows: ((formatEach(scores.\$, "{profile.name}:{score}", ", ")))',
        <String, String>{
          'scores':
              '[{"profile":{"name":"Alice"},"score":7},{"profile":{"name":"Bob"},"score":12}]',
        },
      );

      expect(resolved, 'Rows: Alice:7, Bob:12');
    });

    test('returns empty string for invalid JSON paths or missing values', () {
      final resolved = resolveTemplatePlaceholders(
        'Value=((payload.\$.items[99].name))',
        <String, String>{'payload': '{"items":[{"name":"Alpha"}]}'},
      );

      expect(resolved, 'Value=');
    });

    test('resolves BDFD select collection suffixes', () {
      final resolved = resolveTemplatePlaceholders(
        'Second=((interaction.stringSelect.value[2])) Joined=((interaction.stringSelect.values[, ])) Limited=((interaction.stringSelect.values[/;2]))',
        <String, String>{
          'interaction.stringSelect.value': 'alpha',
          'interaction.stringSelect.values': 'alpha,beta,gamma',
          '__collection.interaction.stringSelect.value':
              '["alpha","beta","gamma"]',
          '__collection.interaction.stringSelect.values':
              '["alpha","beta","gamma"]',
        },
      );

      expect(
        resolved,
        'Second=beta Joined=alpha, beta, gamma Limited=alpha/beta',
      );
    });
  });
}
