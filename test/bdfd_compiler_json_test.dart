import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdCompiler', () {
    test('compiles json helper workflow without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{}]'
        r'$jsonArray[scores]'
        r'$jsonArrayAppend[scores;5]'
        r'$jsonArrayAppend[scores;8]'
        r'$jsonArrayAppend[scores;10]'
        r'$reply$c[]Count=$jsonArrayCount[scores]|Top=$json[ scores;1 ]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(result.actions.single.payload['content'], 'Count=3|Top=8');
    });

    test('compiles jsonKeys to list all keys of root object', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"a":1,"b":2,"c":3}]'
        r'$reply$jsonKeys[]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'a,b,c');
    });

    test('compiles jsonKeys with custom separator', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"x":1,"y":2}]'
        r'$reply$jsonKeys[;|]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'x|y');
    });

    test('compiles jsonKeys at nested path', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"data":{"name":"test","value":42}}]'
        r'$reply$jsonKeys[data]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'name,value');
    });

    test('compiles jsonForEach to jsonForEachLoop action', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"a":1,"b":2}]'
        r'$jsonForEach[]'
        r'$reply$jsonKey=$jsonValue'
        r'$endJsonForEach',
      );

      expect(result.hasErrors, isFalse);
      // jsonParse with a literal embeds the source in the jsonForEachLoop payload
      final feActions = result.actions.where(
        (a) => a.type == BotCreatorActionType.jsonForEachLoop,
      );
      expect(feActions, hasLength(1));
      final payload = feActions.first.payload;
      expect(payload['path'], isEmpty);
      expect(payload['bodyActions'], isA<List>());
      expect((payload['bodyActions'] as List), isNotEmpty);
      expect(payload['source'], '{"a":1,"b":2}');
    });

    test('compiles jsonForEach with nested path', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"data":{"x":1,"y":2}}]'
        r'$jsonForEach[data]'
        r'$reply$jsonKey'
        r'$endJsonForEach',
      );

      expect(result.hasErrors, isFalse);
      final feActions = result.actions.where(
        (a) => a.type == BotCreatorActionType.jsonForEachLoop,
      );
      expect(feActions, hasLength(1));
      final payload = feActions.first.payload;
      expect(payload['path'], ['data']);
    });

    test('compiles jsonForEach with \$jsonIndex placeholder', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"a":1}]'
        r'$jsonForEach[]'
        r'$reply$jsonIndex: $jsonKey=$jsonValue'
        r'$endJsonForEach',
      );

      expect(result.hasErrors, isFalse);
      final feActions = result.actions.where(
        (a) => a.type == BotCreatorActionType.jsonForEachLoop,
      );
      expect(feActions, hasLength(1));
      // Body actions should contain placeholders for jsonindex, jsonkey, jsonvalue
      final bodyActions = feActions.first.payload['bodyActions'] as List;
      expect(bodyActions, isNotEmpty);
      final content =
          (bodyActions.first as Map<String, dynamic>)['payload']?['content'] ??
          '';
      expect(content, contains('((_loop.var.jsonindex))'));
      expect(content, contains('((_loop.var.jsonkey))'));
      expect(content, contains('((_loop.var.jsonvalue))'));
    });

    test('emits diagnostic for unclosed jsonForEach', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{}]'
        r'$jsonForEach[]'
        r'$reply$c[]test',
      );

      // Should still compile but with a diagnostic warning
      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.any((d) => d.message.contains(r'$endJsonForEach')),
        isTrue,
      );
    });

    test('emits diagnostic for standalone endJsonForEach', () {
      final result = BdfdCompiler().compile(
        r'$reply$c[]test'
        r'$endJsonForEach',
      );

      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.any((d) => d.message.contains(r'$jsonForEach')),
        isTrue,
      );
    });

    test('compiles invalid jsonParse without blocking diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{invalid}]'
        r'$reply$c[]Value=$json[user;name]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'Value=');
    });
  });
}
