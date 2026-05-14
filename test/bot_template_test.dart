import 'package:bot_creator_shared/bot/builtin_templates.dart';
import 'package:test/test.dart';

void main() {
  group('BotTemplate', () {
    test('builtInTemplates is not empty', () {
      expect(builtInTemplates, isNotEmpty);
    });

    test('all templates have unique ids', () {
      final ids = builtInTemplates.map((t) => t.id).toSet();
      expect(ids.length, builtInTemplates.length);
    });

    test('all templates have non-empty metadata', () {
      for (final template in builtInTemplates) {
        expect(template.id, isNotEmpty, reason: 'id should not be empty');
        expect(
          template.nameKey,
          isNotEmpty,
          reason: '${template.id} nameKey should not be empty',
        );
        expect(
          template.descriptionKey,
          isNotEmpty,
          reason: '${template.id} descriptionKey should not be empty',
        );
        expect(
          template.iconCodePoint,
          isPositive,
          reason: '${template.id} iconCodePoint should be positive',
        );
        expect(
          template.category,
          isNotEmpty,
          reason: '${template.id} category should not be empty',
        );
      }
    });

    test('all templates have at least one command', () {
      for (final template in builtInTemplates) {
        expect(
          template.commands,
          isNotEmpty,
          reason: '${template.id} should have at least one command',
        );
      }
    });

    test('all command names are valid Discord slash command names', () {
      final validName = RegExp(r'^[a-zA-Z0-9_]{1,32}$');
      // 8ball is allowed by Discord as a special case
      final specialNames = {'8ball'};

      for (final template in builtInTemplates) {
        for (final cmd in template.commands) {
          expect(
            validName.hasMatch(cmd.name) || specialNames.contains(cmd.name),
            isTrue,
            reason: '${template.id}/${cmd.name} is not a valid command name',
          );
        }
      }
    });

    test('all commands have the required data fields', () {
      const requiredKeys = [
        'version',
        'commandType',
        'editorMode',
        'response',
        'actions',
      ];

      for (final template in builtInTemplates) {
        for (final cmd in template.commands) {
          for (final key in requiredKeys) {
            expect(
              cmd.data.containsKey(key),
              isTrue,
              reason: '${template.id}/${cmd.name} data is missing "$key"',
            );
          }
        }
      }
    });

    test('command names are unique within each template', () {
      for (final template in builtInTemplates) {
        final names =
            template.commands.map((c) => c.name.toLowerCase()).toSet();
        expect(
          names.length,
          template.commands.length,
          reason: '${template.id} has duplicate command names',
        );
      }
    });

    test('workflow names are unique within each template', () {
      for (final template in builtInTemplates) {
        if (template.workflows.isEmpty) continue;
        final names =
            template.workflows
                .map((w) => (w['name'] ?? '').toString().toLowerCase())
                .toSet();
        expect(
          names.length,
          template.workflows.length,
          reason: '${template.id} has duplicate workflow names',
        );
      }
    });

    test('welcome template has a guildMemberAdd workflow', () {
      final welcome = builtInTemplates.firstWhere((t) => t.id == 'welcome');
      expect(welcome.workflows, isNotEmpty);
      final trigger =
          welcome.workflows.first['eventTrigger'] as Map<String, dynamic>;
      expect(trigger['event'], 'guildMemberAdd');
    });

    test('moderation template requires ban permissions', () {
      final moderation = builtInTemplates.firstWhere(
        (t) => t.id == 'moderation',
      );
      final banCmd = moderation.commands.firstWhere((c) => c.name == 'ban');
      expect(
        banCmd.data['defaultMemberPermissions'],
        isNotEmpty,
        reason: 'ban command should require permissions',
      );
    });
  });
}
