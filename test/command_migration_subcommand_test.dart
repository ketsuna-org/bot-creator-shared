import 'package:bot_creator_shared/utils/command_migration.dart';
import 'package:test/test.dart';

void main() {
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

  group('migrateCommandDataResponse — subcommand workflows', () {
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
