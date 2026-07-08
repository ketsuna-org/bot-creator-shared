import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_shared/utils/intent_resolver.dart';
import 'package:nyxx/nyxx.dart';

/// Privileged intent keys enabled in the Discord Developer Portal for [app].
Set<String> portalEnabledPrivilegedIntentsFromApplication(Application app) {
  final flags = app.flags;
  final enabled = <String>{};

  if (flags.hasGatewayGuildMembers || flags.hasGatewayGuildMembersLimited) {
    enabled.add('Guild Members');
  }
  if (flags.hasGatewayPresence || flags.hasGatewayPresenceLimited) {
    enabled.add('Guild Presence');
  }
  if (flags.hasGatewayMessageContent || flags.hasGatewayMessageContentLimited) {
    enabled.add('Message Content');
  }

  return enabled;
}

/// Full intents map reflecting portal flags (non-privileged always on).
Map<String, bool> buildPortalIntentsMap(Application app) {
  final portalPrivileged = portalEnabledPrivilegedIntentsFromApplication(app);

  return {
    'Guilds': true,
    'Guild Messages': true,
    'Direct Messages': true,
    'Guild Message Reactions': true,
    'Direct Message Reactions': true,
    'Guild Message Typing': true,
    'Direct Message Typing': true,
    'Guild Scheduled Events': true,
    'Auto Moderation Configuration': true,
    'Auto Moderation Execution': true,
    'Guild Moderation': true,
    'Guild Expressions': true,
    'Guild Integrations': true,
    'Guild Webhooks': true,
    'Guild Invites': true,
    'Guild Voice States': true,
    'Guild Message Polls': true,
    'Direct Message Polls': true,
    'Guild Members': portalPrivileged.contains('Guild Members'),
    'Guild Presence': portalPrivileged.contains('Guild Presence'),
    'Message Content': portalPrivileged.contains('Message Content'),
  };
}

bool botConfigHasLegacyCommands(BotConfig config) {
  if (config.builtInLegacyHelpEnabled) {
    return true;
  }

  for (final command in config.commands) {
    final data = command['data'];
    if (data is! Map) continue;
    final map = Map<String, dynamic>.from(data);
    if (map['legacyModeEnabled'] != true) continue;

    final type = (command['type'] ?? map['commandType'] ?? '').toString();
    if (type == 'chatInput' || type.isEmpty) {
      return true;
    }
  }
  return false;
}

/// Effective intents for gateway identify: portal base map with privileged keys
/// set to true only when required by bot config AND enabled in the portal.
Map<String, bool> buildEffectiveIntentsMap({
  required BotConfig config,
  required Set<String> portalEnabledPrivileged,
  List<String>? warnings,
}) {
  final portalMap = <String, bool>{
    for (final key in allIntentKeys) key: !privilegedIntentKeys.contains(key),
    for (final key in portalEnabledPrivileged) key: true,
  };

  final requiredKeys = resolveRequiredIntentKeys(
    eventWorkflows: config.workflows,
    hasLegacyCommands: botConfigHasLegacyCommands(config),
    approvedPrivilegedIntents: portalEnabledPrivileged,
    warnings: warnings,
  );

  final effective = Map<String, bool>.from(portalMap);
  for (final key in privilegedIntentKeys) {
    effective[key] =
        requiredKeys.contains(key) && portalEnabledPrivileged.contains(key);
  }

  return effective;
}

/// Safe fallback when portal sync fails: strip all privileged intents.
Map<String, bool> buildSafeFallbackIntentsMap({
  required BotConfig config,
  List<String>? warnings,
}) {
  warnings?.add(
    'Could not sync intents from Discord Developer Portal — '
    'privileged intents disabled for this connection.',
  );

  return buildEffectiveIntentsMap(
    config: config,
    portalEnabledPrivileged: const {},
    warnings: warnings,
  );
}

/// Builds the gateway intent bitmask from an effective intents map.
Flags<GatewayIntents> buildGatewayIntents(Map<String, bool> effectiveMap) {
  Flags<GatewayIntents> intents = GatewayIntents.allUnprivileged;

  if (effectiveMap['Guild Members'] == true) {
    intents |= GatewayIntents.guildMembers;
  }
  if (effectiveMap['Guild Presence'] == true) {
    intents |= GatewayIntents.guildPresences;
  }
  if (effectiveMap['Message Content'] == true) {
    intents |= GatewayIntents.messageContent;
  }

  return intents;
}
