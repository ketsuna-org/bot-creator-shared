/// Maps Discord gateway event names to the intent key(s) they require.
///
/// Intent keys match the labels used in [BotConfig.intents] and
/// the constants in nyxx's `GatewayIntents`.
///
/// Reference: https://discord.com/developers/docs/events/gateway-events#receive-events
library;

/// All known intent keys.
const Set<String> allIntentKeys = {
  'Guilds',
  'Guild Members',
  'Guild Moderation',
  'Guild Expressions',
  'Guild Integrations',
  'Guild Webhooks',
  'Guild Invites',
  'Guild Voice States',
  'Guild Presence',
  'Guild Messages',
  'Guild Message Reactions',
  'Guild Message Typing',
  'Direct Messages',
  'Direct Message Reactions',
  'Direct Message Typing',
  'Message Content',
  'Guild Scheduled Events',
  'Auto Moderation Configuration',
  'Auto Moderation Execution',
  'Guild Message Polls',
  'Direct Message Polls',
};

/// Intent keys that require explicit approval in the Discord Developer Portal.
const Set<String> privilegedIntentKeys = {
  'Guild Members',
  'Guild Presence',
  'Message Content',
};

/// Maps a Discord gateway event name (camelCase, as used in workflows)
/// to the set of intent keys it requires.
///
/// Events not listed here (e.g. `ready`, `resumed`, `interactionCreate`,
/// `entitlementCreate`) don't require a specific intent.
const Map<String, Set<String>> eventToIntentKeys = {
  // ── Guilds (bit 0) ──────────────────────────────────────────────
  'guildCreate': {'Guilds'},
  'guildUpdate': {'Guilds'},
  'guildDelete': {'Guilds'},
  'channelCreate': {'Guilds'},
  'channelUpdate': {'Guilds'},
  'channelDelete': {'Guilds'},
  'channelPinsUpdate': {'Guilds'},
  'threadCreate': {'Guilds'},
  'threadUpdate': {'Guilds'},
  'threadDelete': {'Guilds'},
  'threadListSync': {'Guilds'},
  'threadMemberUpdate': {'Guilds'},
  'threadMembersUpdate': {'Guilds'},
  'stageInstanceCreate': {'Guilds'},
  'stageInstanceUpdate': {'Guilds'},
  'stageInstanceDelete': {'Guilds'},

  // ── Guild Members (bit 1, PRIVILEGED) ──────────────────────────
  'guildMemberAdd': {'Guild Members'},
  'guildMemberUpdate': {'Guild Members'},
  'guildMemberRemove': {'Guild Members'},

  // ── Guild Moderation (bit 2) ───────────────────────────────────
  'guildAuditLogCreate': {'Guild Moderation'},
  'guildBanAdd': {'Guild Moderation'},
  'guildBanRemove': {'Guild Moderation'},

  // ── Guild Expressions (bit 3) ──────────────────────────────────
  'guildEmojisUpdate': {'Guild Expressions'},
  'guildStickersUpdate': {'Guild Expressions'},
  'soundboardSoundCreate': {'Guild Expressions'},
  'soundboardSoundUpdate': {'Guild Expressions'},
  'soundboardSoundDelete': {'Guild Expressions'},
  'soundboardSoundsUpdate': {'Guild Expressions'},

  // ── Guild Integrations (bit 4) ─────────────────────────────────
  'guildIntegrationsUpdate': {'Guild Integrations'},
  'integrationCreate': {'Guild Integrations'},
  'integrationUpdate': {'Guild Integrations'},
  'integrationDelete': {'Guild Integrations'},

  // ── Guild Webhooks (bit 5) ─────────────────────────────────────
  'webhooksUpdate': {'Guild Webhooks'},

  // ── Guild Invites (bit 6) ──────────────────────────────────────
  'inviteCreate': {'Guild Invites'},
  'inviteDelete': {'Guild Invites'},

  // ── Guild Voice States (bit 7) ─────────────────────────────────
  'voiceStateUpdate': {'Guild Voice States'},
  'voiceChannelEffectSend': {'Guild Voice States'},

  // ── Guild Presences (bit 8, PRIVILEGED) ────────────────────────
  'presenceUpdate': {'Guild Presence'},

  // ── Guild Messages (bit 9) ─────────────────────────────────────
  'messageCreate': {'Guild Messages'},
  'messageUpdate': {'Guild Messages'},
  'messageDelete': {'Guild Messages'},
  'messageBulkDelete': {'Guild Messages'},

  // ── Guild Message Reactions (bit 10) ───────────────────────────
  'messageReactionAdd': {'Guild Message Reactions'},
  'messageReactionRemove': {'Guild Message Reactions'},
  'messageReactionRemoveAll': {'Guild Message Reactions'},
  'messageReactionRemoveEmoji': {'Guild Message Reactions'},

  // ── Guild Message Typing (bit 11) ──────────────────────────────
  'typingStart': {'Guild Message Typing'},

  // ── Guild Scheduled Events (bit 16) ────────────────────────────
  'guildScheduledEventCreate': {'Guild Scheduled Events'},
  'guildScheduledEventUpdate': {'Guild Scheduled Events'},
  'guildScheduledEventDelete': {'Guild Scheduled Events'},
  'guildScheduledEventUserAdd': {'Guild Scheduled Events'},
  'guildScheduledEventUserRemove': {'Guild Scheduled Events'},

  // ── Auto Moderation Configuration (bit 20) ────────────────────
  'autoModerationRuleCreate': {'Auto Moderation Configuration'},
  'autoModerationRuleUpdate': {'Auto Moderation Configuration'},
  'autoModerationRuleDelete': {'Auto Moderation Configuration'},

  // ── Auto Moderation Execution (bit 21) ─────────────────────────
  'autoModerationActionExecution': {'Auto Moderation Execution'},

  // ── Guild Message Polls (bit 24) ───────────────────────────────
  'messagePollVoteAdd': {'Guild Message Polls'},
  'messagePollVoteRemove': {'Guild Message Polls'},
};

/// Computes the set of intent keys required by the given event workflows and
/// legacy command configuration.
///
/// [eventWorkflows] — the list of event workflow definitions from [BotConfig].
/// [hasLegacyCommands] — whether the bot has at least one enabled legacy command.
/// [approvedPrivilegedIntents] — the set of privileged intent keys that the
///   Discord application has been approved for (fetched from the API). If a
///   required privileged intent is not in this set, it will be excluded and a
///   warning entry will be added to [warnings].
/// [warnings] — optional list that collects human-readable warnings when a
///   required privileged intent is not approved.
Set<String> resolveRequiredIntentKeys({
  required List<Map<String, dynamic>> eventWorkflows,
  required bool hasLegacyCommands,
  Set<String> approvedPrivilegedIntents = const {},
  List<String>? warnings,
}) {
  final required = <String>{};

  // Collect intents from configured event workflows.
  for (final workflow in eventWorkflows) {
    final trigger = workflow['eventTrigger'];
    if (trigger == null) continue;

    final event =
        (trigger is Map ? trigger['event'] : trigger.toString())
            .toString()
            .trim();
    if (event.isEmpty) continue;

    final intents = eventToIntentKeys[event];
    if (intents != null) {
      required.addAll(intents);
    }
  }

  // Legacy (prefix) commands need messageCreate which requires Guild Messages.
  // They also need Message Content to read the prefix and arguments.
  if (hasLegacyCommands) {
    required.add('Guild Messages');
    required.add('Message Content');
  }

  // Gate privileged intents behind Discord approval.
  final resolved = <String>{};
  for (final key in required) {
    if (privilegedIntentKeys.contains(key)) {
      if (approvedPrivilegedIntents.contains(key)) {
        resolved.add(key);
      } else {
        warnings?.add(
          'Intent "$key" is required by your event workflows but is not '
          'approved in the Discord Developer Portal. '
          'The related events will not be received.',
        );
      }
    } else {
      resolved.add(key);
    }
  }

  return resolved;
}
