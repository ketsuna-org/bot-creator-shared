import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdCompiler', () {
    test('compiles thread helpers without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$startThread[Cool Thread;123;;1440;yes]'
        r'$editThread[12345;Cool Thread 😎;no;!unchanged;!unchanged;5]'
        r'$threadAddMember[12345;999]'
        r'$threadRemoveMember[12345;999]'
        r'$reply$c[]Thread created: $startThread[Second Thread;123;;60;yes]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(6));
      expect(result.actions[0].type, BotCreatorActionType.createThread);
      expect(result.actions[1].type, BotCreatorActionType.updateChannel);
      expect(result.actions[2].type, BotCreatorActionType.addThreadMember);
      expect(result.actions[3].type, BotCreatorActionType.removeThreadMember);
      expect(result.actions[4].type, BotCreatorActionType.createThread);
      expect(result.actions[5].type, BotCreatorActionType.sendMessage);
      expect(result.actions[5].payload['targetType'], 'reply');
      expect(
        result.actions[5].payload['content'],
        '((thread.lastId))Thread created: ((thread.lastId))',
      );
    });

    test(
      'compiles additem flow with deferred json stringify into setServerVar payload',
      () {
        final result = BdfdCompiler().compile(
          r'$onlyIf[$argCount>0;usage]'
          r'$jsonParse[$getServerVar[items_db]]'
          r'$jsonArrayAppend[items;$args[2]]'
          r'$setServerVar[items_db;$jsonStringify]'
          r'$reply$c[]ok',
        );

        expect(result.hasErrors, isFalse);

        final runtimeIndex = result.actions.indexWhere(
          (a) => a.type == BotCreatorActionType.runtimeJsonBlock,
        );
        final setVarIndex = result.actions.indexWhere(
          (a) => a.type == BotCreatorActionType.setScopedVariable,
        );

        expect(runtimeIndex, greaterThanOrEqualTo(0));
        expect(setVarIndex, greaterThanOrEqualTo(0));
        expect(runtimeIndex, lessThan(setVarIndex));

        final setPayload = result.actions[setVarIndex].payload;
        expect(setPayload['scope'], 'guild');
        expect(setPayload['key'], 'items_db');

        final value = (setPayload['value'] ?? '').toString();
        expect(value, contains('rtJson_'));
        expect(value, isNot(contains('.json_')));
      },
    );

    test('compiles finditem flow with runtime json before if block', () {
      final result = BdfdCompiler().compile(
        r'$onlyIf[$argCount>0;usage]'
        r'$jsonParse[$getServerVar[items_db]]'
        r'$var[idx;$jsonArrayIndex[items;$args[2]]]'
        r'$if[$var[idx]==-1;$reply$c[]not found;$reply$c[]found at $var[idx]: $json[items;$var[idx]]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].type, BotCreatorActionType.ifBlock);
      expect(result.actions[1].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[2].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[3].type, BotCreatorActionType.ifBlock);

      final tempPayload = result.actions[2].payload;
      expect(tempPayload['key'], 'idx');
      expect((tempPayload['value'] ?? '').toString(), contains('rtJson_'));
      expect((tempPayload['value'] ?? '').toString(), contains('.json_0'));

      final conditionVariable =
          (result.actions[3].payload['condition.variable'] ?? '').toString();
      expect(conditionVariable, '((temp.idx))');

      final elseActions = List<Map<String, dynamic>>.from(
        result.actions[3].payload['elseActions'] as List? ?? const [],
      );
      expect(elseActions, hasLength(2));
      expect(elseActions[0]['type'], 'runtimeJsonBlock');
      expect(elseActions[1]['type'], 'sendMessage');
      expect(
        (elseActions[1]['payload'] as Map<String, dynamic>)['targetType'],
        'reply',
      );

      final elseContent =
          (elseActions[1]['payload'] as Map<String, dynamic>)['content']
              .toString();
      expect(elseContent, contains('((temp.idx))'));
      expect(elseContent, contains('rtJson_1.json_0'));
    });

    test(
      'compiles try block after runtime json with temp runtime var body',
      () {
        final result = BdfdCompiler().compile(
          r'$jsonParse[$getServerVar[items_db]]'
          r'$try'
          r'$var[idx;$jsonArrayIndex[items;$message[1]]]'
          r'$reply$var[idx]'
          r'$catch'
          r'$reply$c[]fallback'
          r'$endtry',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(2));
        expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
        expect(result.actions[1].type, BotCreatorActionType.ifBlock);

        final thenActions = List<Map<String, dynamic>>.from(
          result.actions[1].payload['thenActions'] as List? ?? const [],
        );
        expect(thenActions, hasLength(3));
        expect(thenActions[0]['type'], 'runtimeJsonBlock');
        expect(thenActions[1]['type'], 'setTemporaryVariable');
        expect(thenActions[2]['type'], 'sendMessage');
        expect(
          (thenActions[2]['payload'] as Map<String, dynamic>)['targetType'],
          'reply',
        );

        final bodyJsonPayload = Map<String, dynamic>.from(
          thenActions[0]['payload'] as Map? ?? const <String, dynamic>{},
        );
        expect((bodyJsonPayload['source'] ?? '').toString(), '((rtJson_0))');

        final tempPayload = Map<String, dynamic>.from(
          thenActions[1]['payload'] as Map? ?? const <String, dynamic>{},
        );
        expect(tempPayload['key'], 'idx');
        expect((tempPayload['value'] ?? '').toString(), contains('rtJson_'));
        expect((tempPayload['value'] ?? '').toString(), contains('.json_0'));
        expect(
          (thenActions[2]['payload'] as Map<String, dynamic>)['content'],
          '((temp.idx))',
        );

        final elseActions = List<Map<String, dynamic>>.from(
          result.actions[1].payload['elseActions'] as List? ?? const [],
        );
        expect(elseActions, hasLength(1));
        expect(elseActions.single['type'], 'sendMessage');
        expect(
          (elseActions.single['payload'] as Map<String, dynamic>)['targetType'],
          'reply',
        );
        expect(
          (elseActions.single['payload'] as Map<String, dynamic>)['content'],
          'fallback',
        );
      },
    );

    test('compiles additem flow with literal setServerVar value', () {
      final result = BdfdCompiler().compile(
        r'$onlyIf[$argCount>0;usage]'
        r'$jsonParse[$getServerVar[items_db]]'
        r'$jsonArrayAppend[items;$args[2]]'
        r'$setServerVar[items_db;teststorage]'
        r'$reply$c[]ok',
      );

      expect(result.hasErrors, isFalse);

      final setVarIndex = result.actions.indexWhere(
        (a) => a.type == BotCreatorActionType.setScopedVariable,
      );
      expect(setVarIndex, greaterThanOrEqualTo(0));

      final setPayload = result.actions[setVarIndex].payload;
      expect(setPayload['scope'], 'guild');
      expect(setPayload['key'], 'items_db');
      expect(setPayload['value'], 'teststorage');
    });
  });
}
