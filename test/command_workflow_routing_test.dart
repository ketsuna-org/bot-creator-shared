import 'package:bot_creator_shared/utils/command_workflow_routing.dart';
import 'package:test/test.dart';

void main() {
  group('resolveSubcommandRoute', () {
    test('returns null when options are null', () {
      expect(resolveSubcommandRoute(null), isNull);
    });

    test('returns null when options list is empty', () {
      expect(resolveSubcommandRoute(const <dynamic>[]), isNull);
    });

    test('returns subcommand name for top-level subcommand', () {
      final options = <Map<String, dynamic>>[
        {'type': 'subCommand', 'name': 'ban'},
      ];
      expect(resolveSubcommandRoute(options), 'ban');
    });

    test('returns grouped route for subcommand group', () {
      final options = <Map<String, dynamic>>[
        {
          'type': 'subCommandGroup',
          'name': 'admin',
          'options': <Map<String, dynamic>>[
            {'type': 'subCommand', 'name': 'kick'},
          ],
        },
      ];
      expect(resolveSubcommandRoute(options), 'admin/kick');
    });

    test('supports numeric type 1 for subcommand', () {
      final options = <Map<String, dynamic>>[
        {'type': 1, 'name': 'deploy'},
      ];
      expect(resolveSubcommandRoute(options), 'deploy');
    });

    test('supports numeric type 2 for subcommand group', () {
      final options = <Map<String, dynamic>>[
        {
          'type': 2,
          'name': 'ticket',
          'options': <Map<String, dynamic>>[
            {'type': 1, 'name': 'logchannel'},
          ],
        },
      ];
      expect(resolveSubcommandRoute(options), 'ticket/logchannel');
    });

    test('supports enum-prefixed type strings', () {
      final options = <Map<String, dynamic>>[
        {
          'type': 'CommandOptionType.subCommandGroup',
          'name': 'config',
          'options': <Map<String, dynamic>>[
            {
              'type': 'ApplicationCommandOptionType.subCommand',
              'name': 'status',
            },
          ],
        },
      ];
      expect(resolveSubcommandRoute(options), 'config/status');
    });

    test('ignores non-subcommand option trees', () {
      final options = <Map<String, dynamic>>[
        {'type': 'string', 'name': 'query'},
        {'type': 'integer', 'name': 'count'},
      ];
      expect(resolveSubcommandRoute(options), isNull);
    });

    test('ignores subcommand group without nested subcommands', () {
      final options = <Map<String, dynamic>>[
        {
          'type': 'subCommandGroup',
          'name': 'admin',
          'options': <Map<String, dynamic>>[
            {'type': 'string', 'name': 'query'},
          ],
        },
      ];
      expect(resolveSubcommandRoute(options), isNull);
    });

    test('ignores subcommand group with missing options', () {
      final options = <Map<String, dynamic>>[
        {'type': 'subCommandGroup', 'name': 'admin'},
      ];
      expect(resolveSubcommandRoute(options), isNull);
    });

    test('skips non-subcommand options to find actual subcommand', () {
      final options = <Map<String, dynamic>>[
        {'type': 'string', 'name': 'ignored'},
        {'type': 'subCommand', 'name': 'found'},
      ];
      expect(resolveSubcommandRoute(options), 'found');
    });

    test('handles whitespace in names', () {
      final options = <Map<String, dynamic>>[
        {'type': 'subCommand', 'name': '  spaced  '},
      ];
      expect(resolveSubcommandRoute(options), 'spaced');
    });

    test('returns null when subcommand has empty name', () {
      final options = <Map<String, dynamic>>[
        {'type': 'subCommand', 'name': ''},
      ];
      expect(resolveSubcommandRoute(options), isNull);
    });
  });

  group('resolveSubcommandWorkflowPayload', () {
    test('returns payload for matching route', () {
      final commandValue = <String, dynamic>{
        'subcommandWorkflows': <String, dynamic>{
          'admin/kick': <String, dynamic>{
            'response': <String, dynamic>{'type': 'normal', 'text': 'kicked'},
            'actions': <dynamic>[
              <String, dynamic>{'type': 'logAction'},
            ],
          },
        },
      };

      final payload = resolveSubcommandWorkflowPayload(
        commandValue,
        'admin/kick',
      );
      expect(payload, isNotNull);
      expect((payload!['response'] as Map)['text'], 'kicked');
      expect(payload['actions'], isList);
      expect((payload['actions'] as List).length, 1);
    });

    test('returns null when route is empty', () {
      final commandValue = <String, dynamic>{
        'subcommandWorkflows': <String, dynamic>{
          'ban': <String, dynamic>{'response': <String, dynamic>{}},
        },
      };
      expect(resolveSubcommandWorkflowPayload(commandValue, ''), isNull);
    });

    test('returns null when route is blank', () {
      final commandValue = <String, dynamic>{
        'subcommandWorkflows': <String, dynamic>{
          'ban': <String, dynamic>{'response': <String, dynamic>{}},
        },
      };
      expect(resolveSubcommandWorkflowPayload(commandValue, '   '), isNull);
    });

    test('returns null when route not found', () {
      final commandValue = <String, dynamic>{
        'subcommandWorkflows': <String, dynamic>{
          'ban': <String, dynamic>{'response': <String, dynamic>{}},
        },
      };
      expect(resolveSubcommandWorkflowPayload(commandValue, 'kick'), isNull);
    });

    test('returns null when subcommandWorkflows is absent', () {
      final commandValue = <String, dynamic>{
        'response': <String, dynamic>{'text': 'legacy'},
      };
      expect(resolveSubcommandWorkflowPayload(commandValue, 'ban'), isNull);
    });

    test('returns null when subcommandWorkflows is not a Map', () {
      final commandValue = <String, dynamic>{
        'subcommandWorkflows': 'not a map',
      };
      expect(resolveSubcommandWorkflowPayload(commandValue, 'ban'), isNull);
    });

    test('returns null when payload value is not a Map', () {
      final commandValue = <String, dynamic>{
        'subcommandWorkflows': <String, dynamic>{'ban': 'string payload'},
      };
      expect(resolveSubcommandWorkflowPayload(commandValue, 'ban'), isNull);
    });

    test('each route returns its own independent payload', () {
      final commandValue = <String, dynamic>{
        'subcommandWorkflows': <String, dynamic>{
          'config/status': <String, dynamic>{
            'response': <String, dynamic>{'text': 'status response'},
            'actions': <dynamic>[],
          },
          'config/logchannel': <String, dynamic>{
            'response': <String, dynamic>{'text': 'logchannel response'},
            'actions': <dynamic>[
              <String, dynamic>{'type': 'setChannel'},
            ],
          },
        },
      };

      final status = resolveSubcommandWorkflowPayload(
        commandValue,
        'config/status',
      );
      expect((status!['response'] as Map)['text'], 'status response');
      expect((status['actions'] as List), isEmpty);

      final logchannel = resolveSubcommandWorkflowPayload(
        commandValue,
        'config/logchannel',
      );
      expect((logchannel!['response'] as Map)['text'], 'logchannel response');
      expect((logchannel['actions'] as List).length, 1);
    });
  });

  group('normalizeOptionType', () {
    test('normalizes string subCommand', () {
      expect(normalizeOptionType('subCommand'), 'subcommand');
    });

    test('normalizes string subCommandGroup', () {
      expect(normalizeOptionType('subCommandGroup'), 'subcommandgroup');
    });

    test('normalizes numeric 1 to subcommand', () {
      expect(normalizeOptionType(1), 'subcommand');
    });

    test('normalizes numeric 2 to subcommandgroup', () {
      expect(normalizeOptionType(2), 'subcommandgroup');
    });

    test('normalizes double 1.0 to subcommand', () {
      expect(normalizeOptionType(1.0), 'subcommand');
    });

    test('normalizes prefixed type string', () {
      expect(normalizeOptionType('CommandOptionType.subCommand'), 'subcommand');
      expect(
        normalizeOptionType('CommandOptionType.subCommandGroup'),
        'subcommandgroup',
      );
    });

    test('normalizes other numeric types to their string', () {
      // e.g. type 3 = string
      expect(normalizeOptionType(3), '3');
    });

    test('normalizes plain string types', () {
      expect(normalizeOptionType('string'), 'string');
      expect(normalizeOptionType('integer'), 'integer');
    });
  });

  group('readOptionField', () {
    test('reads from Map', () {
      final option = {'type': 'subCommand', 'name': 'ban'};
      expect(readOptionField(option, 'type'), 'subCommand');
      expect(readOptionField(option, 'name'), 'ban');
    });

    test('returns null for missing key in Map', () {
      final option = <String, dynamic>{'type': 'subCommand'};
      expect(readOptionField(option, 'options'), isNull);
    });

    test('returns null for non-Map non-object', () {
      expect(readOptionField('string', 'type'), isNull);
      expect(readOptionField(42, 'name'), isNull);
    });
  });

  group('normalizeOptionName', () {
    test('trims whitespace', () {
      expect(normalizeOptionName('  hello  '), 'hello');
    });

    test('handles null', () {
      expect(normalizeOptionName(null), '');
    });

    test('converts non-string to string', () {
      expect(normalizeOptionName(42), '42');
    });
  });
}
