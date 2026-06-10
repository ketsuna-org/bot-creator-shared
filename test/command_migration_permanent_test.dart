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

  group('migrateCommandDataResponsePermanently', () {
    test('migrates and empties response', () {
      final data = commandData(
        response: {
          'text': 'Pong!',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
      );
      final result = migrateCommandDataResponsePermanently(data);
      expect(result, isTrue);
      // Actions should contain the respondWithMessage.
      final actions = data['actions'] as List;
      expect(actions.any((a) => a['type'] == 'respondWithMessage'), isTrue);
      expect(
        actions.firstWhere((a) => a['type'] == 'respondWithMessage')['payload']['content'],
        equals('Pong!'),
      );
      // Response should be empty.
      final response = data['response'] as Map;
      expect(response['text'], equals(''));
      expect(response['embeds'], isEmpty);
      expect(response['mode'], equals('message'));
    });

    test('no-op on empty response', () {
      final data = commandData(
        response: {
          'type': 'normal',
          'text': '',
          'embeds': [],
          'workflow': {'visibility': 'public', 'conditional': {'enabled': false}},
        },
      );
      final result = migrateCommandDataResponsePermanently(data);
      expect(result, isFalse);
    });

    test('idempotent — calling twice has no effect second time', () {
      final data = commandData(
        response: {
          'text': 'Hello',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
      );
      final first = migrateCommandDataResponsePermanently(data);
      expect(first, isTrue);
      final second = migrateCommandDataResponsePermanently(data);
      expect(second, isFalse);
      // Only one respondWithMessage action.
      expect(
        (data['actions'] as List)
            .where((a) => a['type'] == 'respondWithMessage')
            .length,
        equals(1),
      );
    });

    test('migrates subcommand workflows permanently', () {
      final data = {
        'actions': [],
        'response': {
          'type': 'normal',
          'text': '',
          'workflow': {'visibility': 'public', 'conditional': {'enabled': false}},
        },
        'subcommandWorkflows': {
          'ban': {
            'response': {
              'text': 'User banned!',
              'type': 'normal',
              'workflow': {'visibility': 'public'},
            },
            'actions': [],
          },
        },
      };
      final result = migrateCommandDataResponsePermanently(data);
      expect(result, isTrue);
      final sub = (data['subcommandWorkflows'] as Map)['ban'] as Map;
      expect(
        (sub['actions'] as List).any((a) => a['type'] == 'respondWithMessage'),
        isTrue,
      );
      expect((sub['response'] as Map)['text'], equals(''));
    });

    test('response with existing respondWithMessage — empties response only', () {
      final data = commandData(
        response: {
          'text': 'Pong!',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
        actions: [
          {'type': 'respondWithMessage', 'payload': {'content': 'Already here'}},
        ],
      );
      final result = migrateCommandDataResponsePermanently(data);
      expect(result, isTrue);
      // Should NOT add a duplicate respondWithMessage.
      final respondCount = (data['actions'] as List)
          .where((a) => a['type'] == 'respondWithMessage')
          .length;
      expect(respondCount, equals(1));
      // Response should be empty.
      expect((data['response'] as Map)['text'], equals(''));
    });

    test('preserves existing non-respond actions after migration', () {
      final data = commandData(
        response: {
          'text': 'Result!',
          'type': 'normal',
          'workflow': {'visibility': 'public'},
        },
        actions: [
          {'type': 'setVariable', 'payload': {'name': 'x', 'value': '1'}},
        ],
      );
      final result = migrateCommandDataResponsePermanently(data);
      expect(result, isTrue);
      final actions = data['actions'] as List;
      // Should have setVariable + respondWithMessage (no defer since count ≤ threshold).
      expect(actions.length, equals(2));
      expect(actions[0]['type'], equals('setVariable'));
      expect(actions[1]['type'], equals('respondWithMessage'));
    });

    test('heavy action triggers defer during permanent migration', () {
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
      final result = migrateCommandDataResponsePermanently(data);
      expect(result, isTrue);
      final actions = data['actions'] as List;
      // deferInteraction + banUser + respondWithMessage.
      expect(actions[0]['type'], equals('deferInteraction'));
      expect(actions[1]['type'], equals('banUser'));
      expect(actions[2]['type'], equals('respondWithMessage'));
    });
  });
}
