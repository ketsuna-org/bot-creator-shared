import 'package:bot_creator_shared/utils/command_migration.dart';
import 'package:test/test.dart';

void main() {
  // Helper to build a minimal command data map.
  Map<String, dynamic> commandData({
    Map<String, dynamic> response = const {},
    List<Map<String, dynamic>> actions = const [],
  }) {
    return {
      'actions': List<Map<String, dynamic>>.from(actions),
      'response': Map<String, dynamic>.from(response),
    };
  }

  group('migrateCommandDataResponse — no migration needed', () {
    test('empty response → no actions injected', () {
      final data = commandData(response: {});
      migrateCommandDataResponse(data);
      expect((data['actions'] as List).isEmpty, isTrue);
    });

    test('already migrated sentinel → idempotent', () {
      final data = commandData(
        response: {
          '_migrated': true,
          'text': 'Hello',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
      );
      migrateCommandDataResponse(data);
      // No actions injected because sentinel is set.
      expect((data['actions'] as List).isEmpty, isTrue);
    });

    test('existing respondWithMessage action → no migration', () {
      final data = commandData(
        response: {'text': 'Pong!', 'type': 'normal'},
        actions: [
          {'type': 'respondWithMessage', 'payload': {'content': 'Already set'}},
        ],
      );
      migrateCommandDataResponse(data);
      // Still just the one explicit action.
      expect((data['actions'] as List).length, equals(1));
    });

    test('response with no text/embeds/conditional → no migration', () {
      final data = commandData(
        response: {
          'type': 'normal',
          'text': '',
          'embeds': [],
          'workflow': {'visibility': 'public', 'conditional': {'enabled': false}},
        },
      );
      migrateCommandDataResponse(data);
      expect((data['actions'] as List).isEmpty, isTrue);
    });
  });

  group('migrateCommandDataResponse — simple text response', () {
    test('text response → respondWithMessage injected', () {
      final data = commandData(
        response: {
          'text': 'Pong!',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      expect(actions.length, equals(1));
      expect(actions.first['type'], equals('respondWithMessage'));
      expect(actions.first['payload']['content'], equals('Pong!'));
      expect(actions.first['payload']['ephemeral'], isFalse);
    });

    test('ephemeral response → ephemeral: true in payload', () {
      final data = commandData(
        response: {
          'text': 'Secret',
          'type': 'normal',
          'workflow': {'visibility': 'ephemeral'},
        },
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      expect(actions.first['payload']['ephemeral'], isTrue);
    });

    test('response with embed → embed in payload', () {
      final data = commandData(
        response: {
          'text': '',
          'embeds': [{'title': 'Hello', 'color': 123}],
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      expect(actions.first['type'], equals('respondWithMessage'));
      final embeds = actions.first['payload']['embeds'] as List;
      expect(embeds.length, equals(1));
      expect(embeds.first['title'], equals('Hello'));
    });
  });

  group('migrateCommandDataResponse — componentV2 response', () {
    test('componentV2 type → respondWithComponentV2', () {
      final data = commandData(
        response: {
          'type': 'componentV2',
          'components': {'type': 'container', 'components': []},
          'workflow': {'visibility': 'public'},
        },
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      expect(actions.first['type'], equals('respondWithComponentV2'));
    });
  });

  group('migrateCommandDataResponse — modal response', () {
    test('modal mode → respondWithModal', () {
      final data = commandData(
        response: {
          'mode': 'modal',
          'modal': {'title': 'My Modal', 'customId': 'my_modal', 'inputs': []},
        },
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      expect(actions.first['type'], equals('respondWithModal'));
      expect(actions.first['payload']['modal']['title'], equals('My Modal'));
    });
  });

  group('migrateCommandDataResponse — defer injection', () {
    test('≤ 2 total actions → no deferInteraction', () {
      // 0 existing + 1 respond = 1 total → no defer
      final data = commandData(
        response: {
          'text': 'Hi',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
        actions: [],
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      expect(
        actions.any((a) => a['type'] == 'deferInteraction'),
        isFalse,
      );
    });

    test('> 2 total actions → deferInteraction prepended', () {
      // 2 existing + 1 respond = 3 total → defer injected
      final data = commandData(
        response: {
          'text': 'Hi',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
        actions: [
          {'type': 'banUser', 'payload': {}},
          {'type': 'kickUser', 'payload': {}},
        ],
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      expect(actions.first['type'], equals('deferInteraction'));
    });

    test('ephemeral + defer → deferInteraction has ephemeral: true', () {
      final data = commandData(
        response: {
          'text': 'Secret',
          'type': 'normal',
          'workflow': {'visibility': 'ephemeral'},
        },
        actions: [
          {'type': 'banUser', 'payload': {}},
          {'type': 'kickUser', 'payload': {}},
        ],
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      expect(actions.first['type'], equals('deferInteraction'));
      expect(actions.first['payload']['ephemeral'], isTrue);
    });
  });

  group('migrateCommandDataResponse — conditional (ifBlock)', () {
    test('conditional enabled → ifBlock generated', () {
      final data = commandData(
        response: {
          'text': '',
          'type': 'normal',
          'workflow': {
            'visibility': 'public',
            'conditional': {
              'enabled': true,
              'variable': '((coin()))',
              'whenTrueType': 'message',
              'whenFalseType': 'message',
              'whenTrueText': 'Heads!',
              'whenFalseText': 'Tails!',
              'whenTrueEmbeds': [],
              'whenFalseEmbeds': [],
            },
          },
        },
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      expect(actions.last['type'], equals('ifBlock'));
      final payload = actions.last['payload'] as Map;
      expect(payload['condition'], equals('((coin()))'));
      final trueActions = payload['actions'] as List;
      final falseActions = payload['elseActions'] as List;
      expect(trueActions.first['payload']['content'], equals('Heads!'));
      expect(falseActions.first['payload']['content'], equals('Tails!'));
    });

    test('conditional branches have independent ephemeral', () {
      final data = commandData(
        response: {
          'text': '',
          'type': 'normal',
          'workflow': {
            'visibility': 'public',
            'conditional': {
              'enabled': true,
              'variable': '((x))',
              'whenTrueType': 'message',
              'whenFalseType': 'message',
              'whenTrueText': 'Yes',
              'whenFalseText': 'No',
              'whenTrueVisibility': 'ephemeral',
              'whenFalseVisibility': 'public',
            },
          },
        },
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      final ifBlock = actions.last;
      final trueActions = ifBlock['payload']['actions'] as List;
      final falseActions = ifBlock['payload']['elseActions'] as List;
      expect(trueActions.first['payload']['ephemeral'], isTrue);
      expect(falseActions.first['payload']['ephemeral'], isFalse);
    });
  });

  group('migrateCommandDataResponse — sentinel marking', () {
    test('_migrated sentinel set after migration', () {
      final data = commandData(
        response: {
          'text': 'Hi',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
      );
      migrateCommandDataResponse(data);
      expect((data['response'] as Map)['_migrated'], isTrue);
    });

    test('double call is idempotent — actions not duplicated', () {
      final data = commandData(
        response: {
          'text': 'Hi',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
      );
      migrateCommandDataResponse(data);
      final countAfterFirst = (data['actions'] as List).length;
      migrateCommandDataResponse(data);
      final countAfterSecond = (data['actions'] as List).length;
      expect(countAfterSecond, equals(countAfterFirst));
    });
  });

  group('migrateCommandDataResponse — heavy action forces defer', () {
    test('single banUser action + response → defer forced', () {
      // 1 heavy existing + 1 respond = 2 total, but heavy action forces defer.
      final data = commandData(
        response: {
          'text': 'Banned!',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
        actions: [
          {'type': 'banUser', 'payload': {}},
        ],
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      expect(actions.first['type'], equals('deferInteraction'));
    });

    test('single httpRequest action + response → defer forced', () {
      final data = commandData(
        response: {
          'text': 'Done',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
        actions: [
          {'type': 'httpRequest', 'payload': {}},
        ],
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      expect(actions.first['type'], equals('deferInteraction'));
    });

    test('lightweight action only → no forced defer', () {
      // setVariable is lightweight — defer only on count threshold.
      final data = commandData(
        response: {
          'text': 'Hi',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
        actions: [
          {'type': 'setVariable', 'payload': {}},
        ],
      );
      migrateCommandDataResponse(data);
      final actions = data['actions'] as List;
      expect(
        actions.any((a) => a['type'] == 'deferInteraction'),
        isFalse,
      );
    });
  });

  group('migrateCommandDataResponse — subcommand workflows', () {
    Map<String, dynamic> commandWithSubcommand({
      Map<String, dynamic> rootResponse = const {},
      List<Map<String, dynamic>> rootActions = const [],
      Map<String, Map<String, dynamic>>? subcommandWorkflows,
    }) {
      final data = {
        'actions': List<Map<String, dynamic>>.from(rootActions),
        'response': Map<String, dynamic>.from(rootResponse),
        if (subcommandWorkflows != null)
          'subcommandWorkflows': Map<String, dynamic>.from(subcommandWorkflows),
      };
      return data;
    }

    test('subcommand with legacy response → migrated', () {
      final data = commandWithSubcommand(
        rootResponse: {'type': 'normal', 'text': '', 'workflow': {'visibility': 'public', 'conditional': {'enabled': false}}},
        subcommandWorkflows: {
          'ban': {
            'response': {
              'text': 'User banned!',
              'type': 'normal',
              'workflow': {'visibility': 'public'},
            },
            'actions': [],
          },
        },
      );
      migrateCommandDataResponse(data);
      final sub = (data['subcommandWorkflows'] as Map)['ban'] as Map;
      final actions = sub['actions'] as List;
      expect(actions.length, equals(1));
      expect(actions.first['type'], equals('respondWithMessage'));
      expect(actions.first['payload']['content'], equals('User banned!'));
      expect((sub['response'] as Map)['_migrated'], isTrue);
    });

    test('subcommand with heavy action → defer forced', () {
      final data = commandWithSubcommand(
        rootResponse: {'type': 'normal', 'text': '', 'workflow': {'visibility': 'public', 'conditional': {'enabled': false}}},
        subcommandWorkflows: {
          'ban': {
            'response': {
              'text': 'Done',
              'type': 'normal',
              'workflow': {'visibility': 'public'},
            },
            'actions': [
              {'type': 'banUser', 'payload': {}},
            ],
          },
        },
      );
      migrateCommandDataResponse(data);
      final sub = (data['subcommandWorkflows'] as Map)['ban'] as Map;
      final actions = sub['actions'] as List;
      expect(actions.first['type'], equals('deferInteraction'));
    });

    test('subcommand without response → no migration', () {
      final data = commandWithSubcommand(
        rootResponse: {'type': 'normal', 'text': '', 'workflow': {'visibility': 'public', 'conditional': {'enabled': false}}},
        subcommandWorkflows: {
          'ban': {
            'actions': [],
          },
        },
      );
      migrateCommandDataResponse(data);
      final sub = (data['subcommandWorkflows'] as Map)['ban'] as Map;
      final actions = sub['actions'] as List;
      expect(actions.isEmpty, isTrue);
    });

    test('subcommand with _migrated sentinel → skipped', () {
      final data = commandWithSubcommand(
        rootResponse: {'type': 'normal', 'text': '', 'workflow': {'visibility': 'public', 'conditional': {'enabled': false}}},
        subcommandWorkflows: {
          'ban': {
            'response': {
              '_migrated': true,
              'text': 'Already done',
              'type': 'normal',
            },
            'actions': [],
          },
        },
      );
      migrateCommandDataResponse(data);
      final sub = (data['subcommandWorkflows'] as Map)['ban'] as Map;
      final actions = sub['actions'] as List;
      expect(actions.isEmpty, isTrue);
    });

    test('multiple subcommands → all migrated', () {
      final data = commandWithSubcommand(
        rootResponse: {'type': 'normal', 'text': '', 'workflow': {'visibility': 'public', 'conditional': {'enabled': false}}},
        subcommandWorkflows: {
          'ban': {
            'response': {
              'text': 'Banned!',
              'type': 'normal',
              'workflow': {'visibility': 'public'},
            },
            'actions': [],
          },
          'kick': {
            'response': {
              'text': 'Kicked!',
              'type': 'normal',
              'workflow': {'visibility': 'ephemeral'},
            },
            'actions': [],
          },
        },
      );
      migrateCommandDataResponse(data);
      final workflows = data['subcommandWorkflows'] as Map;
      final banActions = (workflows['ban'] as Map)['actions'] as List;
      final kickActions = (workflows['kick'] as Map)['actions'] as List;
      expect(banActions.length, equals(1));
      expect(banActions.first['payload']['content'], equals('Banned!'));
      expect(kickActions.length, equals(1));
      expect(kickActions.first['payload']['content'], equals('Kicked!'));
      expect(kickActions.first['payload']['ephemeral'], isTrue);
    });
  });
}
