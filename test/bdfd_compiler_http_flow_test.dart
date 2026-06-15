import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdCompiler', () {
    test('compiles BDFD http helpers to httpRequest and placeholders', () {
      final result = BdfdCompiler().compile(
        r'$httpAddHeader[content-type;application/x-www-form-urlencoded]'
        r'$httpPost[https://pastebin.com/api/api_post.php;api_option=paste]'
        r'$reply$httpStatus|$httpResult',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions.first.type, BotCreatorActionType.httpRequest);
      expect(result.actions.first.payload['method'], 'POST');
      expect(result.actions.first.payload['bodyText'], 'api_option=paste');
      expect(result.actions.first.payload['headers'], {
        'content-type': 'application/x-www-form-urlencoded',
      });
      expect(
        result.actions.last.payload['content'],
        '((http.status))|((http.body))',
      );
    });

    test('surfaces httpStatus before request as compile error', () {
      final result = BdfdCompiler().compile(r'$reply$httpStatus');

      expect(result.hasErrors, isTrue);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$httpStatus');
    });

    test('compiles awaitFunc to scoped awaited registration action', () {
      final result = BdfdCompiler().compile(
        r'$reply$c[]What do you want me to say?$awaitFunc[say]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      // awaitFunc is a side-effect action — no longer flushes pending content,
      // so it appears before the response.
      expect(result.actions.first.type, BotCreatorActionType.setScopedVariable);
      expect(result.actions.first.payload['scope'], 'user');
      expect(result.actions.first.payload['key'], 'await_say');
      expect(result.actions.first.payload['valueType'], 'json');
      expect(
        (result.actions.first.payload['jsonValue'] as String),
        contains('"name":"say"'),
      );
    });

    test('compiles block if/elseif/else/endif and logical conditions', () {
      final result = BdfdCompiler().compile(
        r'$if[$or[((score))>10;((isAdmin))==true]==true]'
        r'Gold\n'
        r'$elseif[((score))==10]'
        r'Silver\n'
        r'$else\n'
        r'Bronze\n'
        r'$endif',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.ifBlock);

      final payload = result.actions.single.payload;
      expect(payload['condition.group'], 'or');

      final elseIfConditions = List<Map<String, dynamic>>.from(
        payload['elseIfConditions'] as List,
      );
      expect(elseIfConditions, hasLength(1));
      expect(elseIfConditions.single['condition.operator'], 'equals');
    });

    test('compiles stop to stop action', () {
      final result = BdfdCompiler().compile(r'$stop');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.stop);
    });
  });
}
