import 'package:bot_creator_shared/events/event_contexts.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

class _FakeComponentData {
  _FakeComponentData({
    required this.customId,
    this.values = const <String>[],
    this.type,
  });

  final String customId;
  final List<String> values;
  final dynamic type;
}

class _FakeModalInput {
  _FakeModalInput(this.customId, this.value);

  final String customId;
  final String value;
}

class _FakeModalRow {
  _FakeModalRow(this.components);

  final List<_FakeModalInput> components;
}

class _FakeModalData {
  _FakeModalData({required this.customId, required this.components});

  final String customId;
  final List<_FakeModalRow> components;
}

class _FakeUserAvatar implements CdnAsset {
  @override
  final String hash = 'dummy';
  @override
  final bool isAnimated = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeUser implements User {
  _FakeUser(this.idString);

  final String idString;

  @override
  Snowflake get id => Snowflake(int.parse(idString));

  @override
  final String username = 'TestUser';
  @override
  final String discriminator = '0000';
  @override
  final CdnAsset avatar = _FakeUserAvatar();
  @override
  final String? globalName = 'Test User';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeMember implements Member {
  _FakeMember(this.user);

  @override
  final User user;

  @override
  Snowflake get id => user.id;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGuildsManager implements GuildManager {
  @override
  final cache = _FakeCache<Guild>();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCache<T> implements Cache<T> {
  @override
  final int length = 0;

  @override
  final Iterable<T> values = const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNyxxGateway implements NyxxGateway {
  @override
  final user = _FakeUser('999');
  @override
  final guilds = _FakeGuildsManager();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInteractionManager implements InteractionManager {
  _FakeInteractionManager(this.client);

  @override
  final NyxxGateway client;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInteraction implements Interaction<dynamic> {
  _FakeInteraction({
    required this.data,
    this.user,
    this.member,
    this.channelId,
    this.guildId,
    this.message,
    required this.type,
    InteractionManager? manager,
  }) : manager = manager ?? _FakeInteractionManager(_FakeNyxxGateway());

  @override
  final dynamic data;
  @override
  final User? user;
  @override
  final Member? member;
  @override
  final Snowflake? channelId;
  @override
  final Snowflake? guildId;
  @override
  final Message? message;
  @override
  final InteractionType type;
  @override
  final InteractionManager manager;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMessage implements Message {
  _FakeMessage(this.idString);

  final String idString;

  @override
  Snowflake get id => Snowflake(int.parse(idString));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('buildInteractionRuntimeVariables', () {
    test('extracts button/select routing fields', () {
      final variables = buildInteractionRuntimeVariables(
        _FakeInteraction(
              data: _FakeComponentData(
                customId: 'btn:save',
                values: ['a', 'b'],
              ),
              user: _FakeUser('42'),
              channelId: Snowflake(100),
              guildId: Snowflake(200),
              message: _FakeMessage('300'), type: InteractionType.messageComponent,
            )
            as Interaction<dynamic>,
      );

      expect(variables['interaction.customId'], 'btn:save');
      expect(variables['interaction.values'], 'a,b');
      expect(variables['interaction.values.count'], '2');
      expect(variables['interaction.userId'], '42');
      expect(variables['interaction.channelId'], '100');
      expect(variables['interaction.guildId'], '200');
      expect(variables['interaction.messageId'], '300');
    });

    test('extracts string select aliases with BDFD-compatible access', () {
      final variables = buildInteractionRuntimeVariables(
        _FakeInteraction(
              data: _FakeComponentData(
                customId: 'select:string',
                type: 'stringSelect',
                values: ['alpha', 'beta', 'gamma'],
              ),
            type: InteractionType.messageComponent,
            )
            as Interaction<dynamic>,
      );

      expect(variables['interaction.stringSelect.value'], 'alpha');
      expect(variables['interaction.stringSelect.values'], 'alpha,beta,gamma');
      expect(variables['interaction.stringSelect.count'], '3');
      expect(
        resolveTemplatePlaceholders(
          '((interaction.stringSelect.value[2]))',
          variables,
        ),
        'beta',
      );
      expect(
        resolveTemplatePlaceholders(
          '((interaction.stringSelect.values[/]))',
          variables,
        ),
        'alpha/beta/gamma',
      );
      expect(
        resolveTemplatePlaceholders(
          '((interaction.stringSelect.values[/;2]))',
          variables,
        ),
        'alpha/beta',
      );
    });

    test('extracts channel select aliases and count', () {
      final variables = buildInteractionRuntimeVariables(
        _FakeInteraction(
              data: _FakeComponentData(
                customId: 'select:channel',
                type: 'channelSelect',
                values: ['10', '20'],
              ),
            type: InteractionType.messageComponent,
            )
            as Interaction<dynamic>,
      );

      expect(variables['interaction.channelSelect.channelId'], '10');
      expect(variables['interaction.channelSelect.channelIds'], '10,20');
      expect(variables['interaction.channelSelect.channelCount'], '2');
      expect(
        resolveTemplatePlaceholders(
          '((interaction.channelSelect.channelId[1]))',
          variables,
        ),
        '10',
      );
    });

    test('extracts modal fields values', () {
      final variables = buildInteractionRuntimeVariables(
        _FakeInteraction(
              data: _FakeModalData(
                customId: 'modal:feedback',
                components: <_FakeModalRow>[
                  _FakeModalRow(<_FakeModalInput>[
                    _FakeModalInput('title', 'Hello'),
                    _FakeModalInput('body', 'World'),
                  ]),
                ],
              ),
              type: InteractionType.modalSubmit,
              member: _FakeMember(_FakeUser('77')),
            )
            as Interaction<dynamic>,
      );

      expect(variables['modal.customId'], 'modal:feedback');
      expect(variables['modal.title'], 'Hello');
      expect(variables['opts.title'], 'Hello');
      expect(variables['arg.title'], 'Hello');
      expect(variables['workflow.arg.title'], 'Hello');
      expect(variables['modal.body'], 'World');
      expect(variables['opts.body'], 'World');
      expect(variables['arg.body'], 'World');
      expect(variables['workflow.arg.body'], 'World');
      expect(variables['interaction.userId'], '77');
    });
  });

  group('generateKeyValues command options prefixing', () {
    test('extracts slash command options under all three namespaces', () async {
      final fakeData = _FakeApplicationCommandInteractionData(
        name: 'test_cmd',
        id: Snowflake(111),
        options: [
          _FakeInteractionOption(
            name: 'target',
            value: '555',
            type: CommandOptionType.string,
          ),
          _FakeInteractionOption(
            name: 'reason',
            value: 'Banned for spam',
            type: CommandOptionType.string,
          ),
        ],
      );

      final fakeInteraction = _FakeApplicationCommandInteraction(
        data: fakeData,
        type: InteractionType.applicationCommand,
        user: _FakeUser('77'),
      );

      final keyValues = await generateKeyValues(
        fakeInteraction,
      );

      // Verify that all options are present with all three prefixes
      expect(keyValues['opts.target'], '555');
      expect(keyValues['arg.target'], '555');
      expect(keyValues['workflow.arg.target'], '555');

      expect(keyValues['opts.reason'], 'Banned for spam');
      expect(keyValues['arg.reason'], 'Banned for spam');
      expect(keyValues['workflow.arg.reason'], 'Banned for spam');
    });
  });
}

class _FakeApplicationCommandInteraction implements Interaction<ApplicationCommandInteractionData> {
  _FakeApplicationCommandInteraction({
    required this.data,
    this.user,
    this.member,
    this.channelId,
    this.guildId,
    this.message,
    required this.type,
    InteractionManager? manager,
  }) : manager = manager ?? _FakeInteractionManager(_FakeNyxxGateway());

  @override
  final ApplicationCommandInteractionData data;
  @override
  final User? user;
  @override
  final Member? member;
  @override
  final Snowflake? channelId;
  @override
  final Snowflake? guildId;
  @override
  final PartialGuild? guild = null;
  @override
  final PartialChannel? channel = null;
  @override
  final Message? message;
  @override
  final InteractionType type;
  @override
  final InteractionManager manager;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApplicationCommandInteractionData implements ApplicationCommandInteractionData {
  _FakeApplicationCommandInteractionData({
    required this.name,
    required this.id,
    required this.options,
  });

  @override
  final String name;
  @override
  final Snowflake id;
  @override
  final List<InteractionOption> options;
  @override
  final ApplicationCommandType type = ApplicationCommandType.chatInput;
  @override
  final Snowflake? targetId = null;
  @override
  final ResolvedData? resolved = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInteractionOption implements InteractionOption {
  _FakeInteractionOption({
    required this.name,
    required this.value,
    required this.type,
    this.options = const [],
  });

  @override
  final String name;
  @override
  final dynamic value;
  @override
  final CommandOptionType type;
  @override
  final List<InteractionOption> options;

  @override
  final dynamic focused = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
