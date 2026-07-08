import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_shared/utils/application_intent_sync.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

void main() {
  group('buildEffectiveIntentsMap', () {
    test('enables privileged intent only when required and portal-enabled', () {
      final config = BotConfig(
        token: 'token',
        builtInLegacyHelpEnabled: false,
        workflows: [
          {
            'eventTrigger': {'event': 'guildMemberAdd'},
          },
        ],
      );

      final effective = buildEffectiveIntentsMap(
        config: config,
        portalEnabledPrivileged: {'Guild Members'},
      );

      expect(effective['Guild Members'], isTrue);
      expect(effective['Message Content'], isFalse);
      expect(effective['Guild Presence'], isFalse);
      expect(effective['Guild Messages'], isTrue);
    });

    test('omits privileged intent when portal-disabled even if required', () {
      final warnings = <String>[];
      final config = BotConfig(
        token: 'token',
        builtInLegacyHelpEnabled: false,
        workflows: [
          {
            'eventTrigger': {'event': 'guildMemberAdd'},
          },
        ],
      );

      final effective = buildEffectiveIntentsMap(
        config: config,
        portalEnabledPrivileged: const {},
        warnings: warnings,
      );

      expect(effective['Guild Members'], isFalse);
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('Guild Members'));
    });

    test('does not enable privileged intent when portal on but not required', () {
      final config = const BotConfig(
        token: 'token',
        builtInLegacyHelpEnabled: false,
      );

      final effective = buildEffectiveIntentsMap(
        config: config,
        portalEnabledPrivileged: {'Message Content', 'Guild Members'},
      );

      expect(effective['Message Content'], isFalse);
      expect(effective['Guild Members'], isFalse);
    });

    test('legacy commands require message content when portal-enabled', () {
      final config = BotConfig(
        token: 'token',
        builtInLegacyHelpEnabled: true,
      );

      final effective = buildEffectiveIntentsMap(
        config: config,
        portalEnabledPrivileged: {'Message Content'},
      );

      expect(effective['Message Content'], isTrue);
      expect(effective['Guild Messages'], isTrue);
    });
  });

  group('buildSafeFallbackIntentsMap', () {
    test('forces privileged intents off when portal sync fails', () {
      final warnings = <String>[];
      final config = BotConfig(
        token: 'token',
        builtInLegacyHelpEnabled: true,
      );

      final effective = buildSafeFallbackIntentsMap(
        config: config,
        warnings: warnings,
      );

      expect(effective['Message Content'], isFalse);
      expect(effective['Guild Members'], isFalse);
      expect(effective['Guild Presence'], isFalse);
      expect(warnings, isNotEmpty);
    });
  });

  group('buildGatewayIntents', () {
    test('includes privileged bits only when effective map is true', () {
      final withContent = buildGatewayIntents({
        'Message Content': true,
      });
      final withoutContent = buildGatewayIntents({
        'Message Content': false,
      });

      expect(withContent.has(GatewayIntents.messageContent), isTrue);
      expect(withoutContent.has(GatewayIntents.messageContent), isFalse);
    });
  });
}
