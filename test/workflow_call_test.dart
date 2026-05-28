import 'package:bot_creator_shared/utils/workflow_call.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeStoredWorkflowDefinition', () {
    test('promotes legacy event field into event workflow', () {
      final normalized = normalizeStoredWorkflowDefinition(<String, dynamic>{
        'name': 'Legacy Message Create',
        'event': 'messageCreate',
        'actions': <Map<String, dynamic>>[],
      });

      expect(normalized['workflowType'], workflowTypeEvent);
      expect(normalized['eventTrigger'], <String, dynamic>{
        'category': 'messages',
        'event': 'messageCreate',
      });
    });

    test('promotes legacy listenFor field into event workflow', () {
      final normalized = normalizeStoredWorkflowDefinition(<String, dynamic>{
        'name': 'Legacy Member Add',
        'listenFor': 'guildMemberAdd',
        'actions': <Map<String, dynamic>>[],
      });

      expect(normalized['workflowType'], workflowTypeEvent);
      expect(normalized['eventTrigger'], <String, dynamic>{
        'category': 'messages',
        'event': 'guildMemberAdd',
      });
    });
  });

  group('resolveWorkflowInvocationArguments & applyWorkflowInvocationContext', () {
    test('enforceRequired: true throws exception when required argument is missing or empty', () {
      final definitions = [
        const WorkflowArgumentDefinition(name: 'name', required: true),
      ];

      expect(
        () => resolveWorkflowInvocationArguments(
          definitions: definitions,
          providedArguments: {'name': ' '},
          enforceRequired: true,
        ),
        throwsException,
      );
    });

    test('enforceRequired: false does not throw exception when required argument is missing or empty', () {
      final definitions = [
        const WorkflowArgumentDefinition(name: 'name', required: true),
      ];

      final resolved = resolveWorkflowInvocationArguments(
        definitions: definitions,
        providedArguments: {'name': ' '},
        enforceRequired: false,
      );

      expect(resolved['name'], ' ');
    });

    test('applyWorkflowInvocationContext sets variables correctly when enforceRequired is false', () {
      final variables = <String, String>{};
      final definitions = [
        const WorkflowArgumentDefinition(name: 'name', required: true),
      ];

      applyWorkflowInvocationContext(
        variables: variables,
        workflowName: 'test_workflow',
        entryPoint: 'main',
        definitions: definitions,
        providedArguments: {'name': ''},
        enforceRequired: false,
      );

      expect(variables['workflow.name'], 'test_workflow');
      expect(variables['workflow.entryPoint'], 'main');
      expect(variables['arg.name'], '');
      expect(variables['workflow.arg.name'], '');
      expect(variables['opts.name'], '');
    });
  });
}
