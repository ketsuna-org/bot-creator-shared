import 'package:bot_creator_shared/events/event_contexts.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
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

class _FakeUser {
  _FakeUser(this.id);

  final String id;
}

class _FakeMemberUser {
  _FakeMemberUser(this.id);

  final String id;
}

class _FakeMember {
  _FakeMember(this.user);

  final _FakeMemberUser user;
}

class _FakeInteraction {
  _FakeInteraction({
    required this.data,
    this.user,
    this.member,
    this.channelId,
    this.guildId,
    this.message,
  });

  final dynamic data;
  final dynamic user;
  final dynamic member;
  final dynamic channelId;
  final dynamic guildId;
  final dynamic message;
}

class _FakeMessage {
  _FakeMessage(this.id);

  final String id;
}

void main() {
  group('buildInteractionRuntimeVariables', () {
    test('extracts button/select routing fields', () {
      final variables = buildInteractionRuntimeVariables(
        _FakeInteraction(
          data: _FakeComponentData(customId: 'btn:save', values: ['a', 'b']),
          user: _FakeUser('42'),
          channelId: '100',
          guildId: '200',
          message: _FakeMessage('300'),
        ),
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
        ),
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
        ),
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
          member: _FakeMember(_FakeMemberUser('77')),
        ),
      );

      expect(variables['modal.customId'], 'modal:feedback');
      expect(variables['modal.title'], 'Hello');
      expect(variables['modal.body'], 'World');
      expect(variables['interaction.userId'], '77');
    });
  });
}
