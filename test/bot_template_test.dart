import 'dart:convert';
import 'dart:io';
import 'package:bot_creator_shared/bot/bot_template.dart';
import 'package:test/test.dart';

void main() {
  group('BotTemplate JSON validation', () {
    late List<BotTemplate> templates;

    setUpAll(() {
      final jsonFile = File('template.json');
      final file = jsonFile.existsSync() ? jsonFile : File('packages/shared/template.json');
      expect(file.existsSync(), isTrue, reason: 'template.json must exist');
      final jsonContent = file.readAsStringSync();
      final decoded = jsonDecode(jsonContent);
      expect(decoded, isA<List>());
      templates = (decoded as List)
          .map((item) => BotTemplate.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    });

    test('templates is not empty', () {
      expect(templates, isNotEmpty);
    });

    test('all templates have unique ids', () {
      final ids = templates.map((t) => t.id).toSet();
      expect(ids.length, templates.length);
    });

    test('all templates have non-empty metadata', () {
      for (final template in templates) {
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
      for (final template in templates) {
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

      for (final template in templates) {
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

      for (final template in templates) {
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
      for (final template in templates) {
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
      for (final template in templates) {
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
      final welcome = templates.firstWhere((t) => t.id == 'welcome');
      expect(welcome.workflows, isNotEmpty);
      final trigger =
          welcome.workflows.first['eventTrigger'] as Map<String, dynamic>;
      expect(trigger['event'], 'guildMemberAdd');
    });

    test('moderation template requires ban permissions', () {
      final moderation = templates.firstWhere(
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
