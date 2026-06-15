import 'package:bot_creator_shared/utils/bdfd_lexer.dart';
import 'package:bot_creator_shared/utils/bdfd_parser.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

/// Verifies that $checkCondition defers to runtime when its expression
/// references a runtime-resolved placeholder (regression: previously it
/// baked the literal "false" into the action because the numeric comparator
/// saw a non-numeric operand).
void main() {
  group('checkCondition — compile-time deferral', () {
    BdfdTranspileResult transpile(String src) {
      final lex = BdfdLexer().tokenize(src);
      final parsed = BdfdParser().parseTokens(lex.tokens);
      return BdfdAstTranspiler().transpile(parsed.ast);
    }

    test(
        'expression with a deferred operand emits a runtime placeholder, '
        'not a hardcoded boolean', () {
      final result = transpile(
        r'$var[podeResgatar;$checkCondition[$sub[$gettimestamp;'
        r'$getUserVar[daily_last_timestamp;$authorID]]>=86400]]',
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      final payload = result.actions.single.payload;
      expect(payload['key'], 'podeResgatar');
      final value = payload['value'] as String;
      // Must defer to the runtime handler instead of baking "false".
      expect(value, startsWith('((checkCondition['));
      expect(value, endsWith('))'));
      expect(value, isNot('false'));
      expect(value, isNot('true'));
      // The deferred math ($sub) and timestamp must be preserved inside.
      expect(value, contains('sub['));
      expect(value, contains('getTimestamp'));
    });

    test('static numeric comparison still evaluates at compile time', () {
      // No runtime placeholders -> evaluated statically, not deferred.
      final t = transpile(r'$var[a;$checkCondition[5>=3]]');
      expect(t.actions.single.payload['value'], 'true');

      final f = transpile(r'$var[b;$checkCondition[2>=3]]');
      expect(f.actions.single.payload['value'], 'false');
    });

    test('static equality comparison still evaluates at compile time', () {
      final t = transpile(r'$var[a;$checkCondition[abc==abc]]');
      expect(t.actions.single.payload['value'], 'true');

      final f = transpile(r'$var[b;$checkCondition[abc==xyz]]');
      expect(f.actions.single.payload['value'], 'false');
    });
  });

  group('checkCondition — runtime evaluation', () {
    final now = 1_700_000_000; // fixed epoch seconds

    test('daily cooldown: elapsed >= 86400 -> true', () {
      final value =
          r'((checkCondition[((sub[((getTimestamp));((lastTs))]))>=86400]))';
      final updates = <String, String>{
        'getTimestamp': now.toString(),
        'lastTs': (now - 2 * 86400).toString(), // 2 days ago
      };
      expect(resolveTemplatePlaceholders(value, updates), 'true');
    });

    test('daily cooldown: elapsed < 86400 -> false', () {
      final value =
          r'((checkCondition[((sub[((getTimestamp));((lastTs))]))>=86400]))';
      final updates = <String, String>{
        'getTimestamp': now.toString(),
        'lastTs': (now - 3600).toString(), // 1 hour ago
      };
      expect(resolveTemplatePlaceholders(value, updates), 'false');
    });

    test('>= boundary is inclusive', () {
      final value =
          r'((checkCondition[((sub[((getTimestamp));((lastTs))]))>=86400]))';
      final updates = <String, String>{
        'getTimestamp': now.toString(),
        'lastTs': (now - 86400).toString(), // exactly on the boundary
      };
      expect(resolveTemplatePlaceholders(value, updates), 'true');
    });

    test('other operators (==, !=, <, <=, >) resolve at runtime', () {
      expect(
        resolveTemplatePlaceholders(
            r'((checkCondition[((a))==5]))', <String, String>{'a': '5'}),
        'true',
      );
      expect(
        resolveTemplatePlaceholders(
            r'((checkCondition[((a))!=5]))', <String, String>{'a': '5'}),
        'false',
      );
      expect(
        resolveTemplatePlaceholders(
            r'((checkCondition[((a))<10]))', <String, String>{'a': '3'}),
        'true',
      );
      expect(
        resolveTemplatePlaceholders(
            r'((checkCondition[((a))>10]))', <String, String>{'a': '3'}),
        'false',
      );
    });

    test('empty/missing operand resolves to false, not a crash', () {
      expect(
        resolveTemplatePlaceholders(
            r'((checkCondition[((missing))>=86400]))', <String, String>{}),
        'false',
      );
    });
  });
}
