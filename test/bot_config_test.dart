import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:test/test.dart';

void main() {
  test('BotConfig.fromJson preserves typed global and scoped variables', () {
    final config = BotConfig.fromJson(<String, dynamic>{
      'token': 'discord-token',
      'globalVariables': <String, dynamic>{
        'enabled': true,
        'count': 7,
        'meta': <String, dynamic>{'mode': 'strict'},
      },
      'scopedVariables': <String, dynamic>{
        'guild': <String, dynamic>{
          'guild-1': <String, dynamic>{'score': 9},
        },
        'user': <String, dynamic>{
          'user-1': <String, dynamic>{
            'prefs': <String, dynamic>{'lang': 'en'},
          },
        },
      },
    });

    expect(config.globalVariables['enabled'], isTrue);
    expect(config.globalVariables['count'], 7);
    expect(config.globalVariables['meta'], <String, dynamic>{'mode': 'strict'});
    expect(config.scopedVariables['guild']?['guild-1']?['score'], 9);
    expect(
      config.scopedVariables['user']?['user-1']?['prefs'],
      <String, dynamic>{'lang': 'en'},
    );
  });

  test('BotConfig.fromJson defaults built-in legacy help to enabled', () {
    final config = BotConfig.fromJson(<String, dynamic>{
      'token': 'discord-token',
    });

    expect(config.builtInLegacyHelpEnabled, isTrue);
    expect(config.toJson()['builtInLegacyHelpEnabled'], isTrue);
  });

  test('BotConfig.fromJson preserves disabled built-in legacy help', () {
    final config = BotConfig.fromJson(<String, dynamic>{
      'token': 'discord-token',
      'builtInLegacyHelpEnabled': false,
    });

    expect(config.builtInLegacyHelpEnabled, isFalse);
    expect(config.toJson()['builtInLegacyHelpEnabled'], isFalse);
  });

  test('BotConfig.fromJson upgrades legacy event workflows', () {
    final config = BotConfig.fromJson(<String, dynamic>{
      'token': 'discord-token',
      'workflows': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Legacy Message Create',
          'event': 'messageCreate',
          'actions': <Map<String, dynamic>>[],
        },
      ],
    });

    expect(config.workflows, hasLength(1));
    expect(config.workflows.first['workflowType'], 'event');
    expect(config.workflows.first['eventTrigger'], <String, dynamic>{
      'category': 'messages',
      'event': 'messageCreate',
    });
  });
}
