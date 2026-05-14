import 'package:bot_creator_shared/utils/intent_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('resolveRequiredIntentKeys', () {
    test('returns empty set when no workflows and no legacy commands', () {
      final result = resolveRequiredIntentKeys(
        eventWorkflows: [],
        hasLegacyCommands: false,
        approvedPrivilegedIntents: {},
      );
      expect(result, isEmpty);
    });

    test('adds Guild Messages and Message Content for legacy commands', () {
      final result = resolveRequiredIntentKeys(
        eventWorkflows: [],
        hasLegacyCommands: true,
        approvedPrivilegedIntents: {'Message Content'},
      );
      expect(result, contains('Guild Messages'));
      expect(result, contains('Message Content'));
    });

    test('excludes Message Content for legacy commands when not approved', () {
      final warnings = <String>[];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: [],
        hasLegacyCommands: true,
        approvedPrivilegedIntents: {},
        warnings: warnings,
      );
      expect(result, contains('Guild Messages'));
      expect(result, isNot(contains('Message Content')));
      expect(warnings, hasLength(1));
      expect(warnings.first, contains('Message Content'));
    });

    test('resolves intents from event workflows', () {
      final workflows = [
        {
          'eventTrigger': {'category': 'members', 'event': 'guildMemberAdd'},
        },
        {
          'eventTrigger': {'category': 'messages', 'event': 'messageCreate'},
        },
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
        approvedPrivilegedIntents: {'Guild Members'},
      );
      expect(result, contains('Guild Members'));
      expect(result, contains('Guild Messages'));
    });

    test('gates privileged intent behind approval', () {
      final workflows = [
        {
          'eventTrigger': {'category': 'members', 'event': 'guildMemberAdd'},
        },
      ];
      final warnings = <String>[];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
        approvedPrivilegedIntents: {},
        warnings: warnings,
      );
      expect(result, isNot(contains('Guild Members')));
      expect(warnings, hasLength(1));
      expect(warnings.first, contains('Guild Members'));
    });

    test('allows approved privileged intents', () {
      final workflows = [
        {
          'eventTrigger': {'category': 'presence', 'event': 'presenceUpdate'},
        },
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
        approvedPrivilegedIntents: {'Guild Presence'},
      );
      expect(result, contains('Guild Presence'));
    });

    test('ignores events with no intent mapping (e.g. ready)', () {
      final workflows = [
        {
          'eventTrigger': {'category': 'core', 'event': 'ready'},
        },
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
      );
      expect(result, isEmpty);
    });

    test('resolves auto-moderation intents', () {
      final workflows = [
        {
          'eventTrigger': {
            'category': 'automod',
            'event': 'autoModerationActionExecution',
          },
        },
        {
          'eventTrigger': {
            'category': 'automod',
            'event': 'autoModerationRuleCreate',
          },
        },
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
      );
      expect(result, contains('Auto Moderation Execution'));
      expect(result, contains('Auto Moderation Configuration'));
    });

    test('resolves guild scheduled events intent', () {
      final workflows = [
        {
          'eventTrigger': {
            'category': 'scheduled',
            'event': 'guildScheduledEventCreate',
          },
        },
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
      );
      expect(result, contains('Guild Scheduled Events'));
    });

    test('resolves poll intents', () {
      final workflows = [
        {
          'eventTrigger': {'category': 'polls', 'event': 'messagePollVoteAdd'},
        },
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
      );
      expect(result, contains('Guild Message Polls'));
    });

    test('resolves invite intents', () {
      final workflows = [
        {
          'eventTrigger': {'category': 'invites', 'event': 'inviteCreate'},
        },
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
      );
      expect(result, contains('Guild Invites'));
    });

    test('resolves voice state intents', () {
      final workflows = [
        {
          'eventTrigger': {'category': 'voice', 'event': 'voiceStateUpdate'},
        },
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
      );
      expect(result, contains('Guild Voice States'));
    });

    test('resolves webhook intents', () {
      final workflows = [
        {
          'eventTrigger': {'category': 'webhooks', 'event': 'webhooksUpdate'},
        },
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
      );
      expect(result, contains('Guild Webhooks'));
    });

    test('resolves moderation intents', () {
      final workflows = [
        {
          'eventTrigger': {'category': 'moderation', 'event': 'guildBanAdd'},
        },
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
      );
      expect(result, contains('Guild Moderation'));
    });

    test('resolves expression intents from soundboard events', () {
      final workflows = [
        {
          'eventTrigger': {
            'category': 'soundboard',
            'event': 'soundboardSoundCreate',
          },
        },
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
      );
      expect(result, contains('Guild Expressions'));
    });

    test('deduplicates intents from multiple events', () {
      final workflows = [
        {
          'eventTrigger': {'category': 'messages', 'event': 'messageCreate'},
        },
        {
          'eventTrigger': {'category': 'messages', 'event': 'messageDelete'},
        },
        {
          'eventTrigger': {
            'category': 'messages',
            'event': 'messageBulkDelete',
          },
        },
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
      );
      expect(result, equals({'Guild Messages'}));
    });

    test('handles workflows with missing eventTrigger', () {
      final workflows = <Map<String, dynamic>>[
        {'name': 'test'},
      ];
      final result = resolveRequiredIntentKeys(
        eventWorkflows: workflows,
        hasLegacyCommands: false,
      );
      expect(result, isEmpty);
    });
  });

  group('eventToIntentKeys', () {
    test('all mapped events map to valid intent keys', () {
      for (final entry in eventToIntentKeys.entries) {
        for (final key in entry.value) {
          expect(
            allIntentKeys,
            contains(key),
            reason: 'Event "${entry.key}" maps to unknown intent key "$key"',
          );
        }
      }
    });
  });

  group('privilegedIntentKeys', () {
    test('are a subset of allIntentKeys', () {
      expect(allIntentKeys.containsAll(privilegedIntentKeys), isTrue);
    });
  });
}
