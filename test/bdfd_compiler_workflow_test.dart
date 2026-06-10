import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:test/test.dart';

void main() {
  group(r'$callWorkflow', () {
    test('simple call with name only', () {
      final result = BdfdCompiler().compile(r'$callWorkflow[myFlow]');
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runWorkflow);
      expect(result.actions[0].payload['workflowName'], 'myFlow');
      expect(result.actions[0].payload.containsKey('arguments'), isFalse);
    });

    test('call with positional arguments', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow;hello;world]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['workflowName'], 'myFlow');
      expect(result.actions[0].payload['arguments'], {
        '1': 'hello',
        '2': 'world',
      });
    });

    test('call with key=value arguments', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow;user=Alice;count=3]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['arguments'], {
        'user': 'Alice',
        'count': '3',
      });
    });

    test('call with mixed positional and key=value arguments', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow;hello;key=val]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['arguments'], {
        '1': 'hello',
        'key': 'val',
      });
    });

    test('missing workflow name emits diagnostic', () {
      final result = BdfdCompiler().compile(r'$callWorkflow[]');
      expect(result.actions, isEmpty);
      expect(result.diagnostics, isNotEmpty);
    });

    test('arguments can use inline BDFD functions', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow;$toUpperCase[hello]]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['arguments'], {'1': 'HELLO'});
    });
  });

  group(r'$workflowResponse', () {
    test('produces placeholder with property path', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow]'
        '\n'
        r'Result: $workflowResponse[status.code]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(
        result.actions[1].payload['content'],
        contains('((workflow.response.status.code))'),
      );
    });

    test('produces placeholder without arguments', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow]'
        '\n'
        r'Result: $workflowResponse',
      );
      expect(result.diagnostics, isEmpty);
      expect(
        result.actions[1].payload['content'],
        contains('((workflow.response))'),
      );
    });

    test('emits diagnostic when no preceding callWorkflow', () {
      final result = BdfdCompiler().compile(
        r'Response: $workflowResponse[data]',
      );
      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.first.message,
        contains('requires a preceding'),
      );
    });

    test('tracks latest callWorkflow across multiple calls', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[flowA]'
        '\n'
        r'$callWorkflow[flowB]'
        '\n'
        r'Result: $workflowResponse[output]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(3));
      // Both callWorkflow actions have distinct keys
      expect(result.actions[0].key, '_bdfd_callworkflow_0');
      expect(result.actions[1].key, '_bdfd_callworkflow_1');
      expect(
        result.actions[2].payload['content'],
        contains('((workflow.response.output))'),
      );
    });

    test('can use inline function in property argument', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow]'
        '\n'
        r'$workflowResponse[$toUpperCase[key]]',
      );
      expect(result.diagnostics, isEmpty);
      expect(
        result.actions[1].payload['content'],
        contains('((workflow.response.KEY))'),
      );
    });
  });
}
