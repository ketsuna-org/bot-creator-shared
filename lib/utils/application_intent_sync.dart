import 'dart:convert';

import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_shared/utils/discord_auth_errors.dart';
import 'package:bot_creator_shared/utils/intent_resolver.dart';
import 'package:http/http.dart' as http;
import 'package:nyxx/nyxx.dart';

const _discordApiBase = 'https://discord.com/api/v10';

const _applicationFlagGatewayPresenceLimited = 1 << 12;
const _applicationFlagGatewayPresence = 1 << 13;
const _applicationFlagGatewayGuildMembersLimited = 1 << 14;
const _applicationFlagGatewayGuildMembers = 1 << 15;
const _applicationFlagGatewayMessageContentLimited = 1 << 18;
const _applicationFlagGatewayMessageContent = 1 << 19;
const _userFlagVerifiedBot = 1 << 16;

/// Thrown when the bot is verified and privileged intents cannot be enabled via API.
class PortalIntentAutoEnableError implements Exception {
  const PortalIntentAutoEnableError([
    this.message =
        'Bot is verified, cannot enable privileged intents automatically. '
        'Please enable them in the Discord Developer Portal.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when PATCH /applications/@me fails to update intent flags.
class PortalIntentPatchFailedException implements Exception {
  PortalIntentPatchFailedException(this.statusCode, [this.detail]);

  final int statusCode;
  final String? detail;

  @override
  String toString() =>
      detail ??
      'Failed to update application flags via PATCH ($statusCode)';
}

/// Privileged intent keys enabled for the given application [flags] bitmask.
Set<String> portalEnabledPrivilegedIntentsFromFlags(int flags) {
  final enabled = <String>{};

  if ((flags & _applicationFlagGatewayGuildMembers) != 0 ||
      (flags & _applicationFlagGatewayGuildMembersLimited) != 0) {
    enabled.add('Guild Members');
  }
  if ((flags & _applicationFlagGatewayPresence) != 0 ||
      (flags & _applicationFlagGatewayPresenceLimited) != 0) {
    enabled.add('Guild Presence');
  }
  if ((flags & _applicationFlagGatewayMessageContent) != 0 ||
      (flags & _applicationFlagGatewayMessageContentLimited) != 0) {
    enabled.add('Message Content');
  }

  return enabled;
}

/// Privileged intent keys enabled in the Discord Developer Portal for [app].
Set<String> portalEnabledPrivilegedIntentsFromApplication(Application app) {
  return portalEnabledPrivilegedIntentsFromFlags(app.flags.value);
}

/// Full intents map reflecting portal-enabled privileged keys.
Map<String, bool> buildPortalIntentsMapFromPrivileged(
  Set<String> portalPrivileged,
) {
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

/// Full intents map reflecting portal flags (non-privileged always on).
Map<String, bool> buildPortalIntentsMap(Application app) {
  return buildPortalIntentsMapFromPrivileged(
    portalEnabledPrivilegedIntentsFromApplication(app),
  );
}

/// Reads privileged intents currently enabled in the Developer Portal.
Future<Set<String>> readPortalEnabledPrivilegedIntents(
  String token, {
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  final ownsClient = client == null;
  try {
    final flags = await _fetchApplicationFlags(token, client: httpClient);
    return portalEnabledPrivilegedIntentsFromFlags(flags);
  } finally {
    if (ownsClient) {
      httpClient.close();
    }
  }
}

/// Result of syncing privileged intents from the Developer Portal.
class PortalPrivilegedIntentSyncResult {
  const PortalPrivilegedIntentSyncResult({
    required this.enabled,
    this.didAutoEnable = false,
  });

  final Set<String> enabled;
  final bool didAutoEnable;
}

/// Fetches portal-enabled privileged intents, auto-enabling missing LIMITED flags
/// via PATCH /applications/@me when allowed.
///
/// Business logic is mirrored in runner-js `application-intent-sync.ts`.
Future<PortalPrivilegedIntentSyncResult> fetchPortalEnabledPrivilegedIntents(
  String token, {
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  final ownsClient = client == null;

  try {
    var flags = await _fetchApplicationFlags(token, client: httpClient);
    var enabled = portalEnabledPrivilegedIntentsFromFlags(flags);

    if (enabled.length >= privilegedIntentKeys.length) {
      return PortalPrivilegedIntentSyncResult(enabled: enabled);
    }

    final userFlags = await _fetchUserFlags(token, client: httpClient);
    if ((userFlags & _userFlagVerifiedBot) != 0) {
      throw const PortalIntentAutoEnableError();
    }

    final hasMembers = enabled.contains('Guild Members');
    final hasPresence = enabled.contains('Guild Presence');
    final hasMessageContent = enabled.contains('Message Content');

    var patchFlags = flags;
    if (!hasMembers) {
      patchFlags |= _applicationFlagGatewayGuildMembersLimited;
    }
    if (!hasPresence) {
      patchFlags |= _applicationFlagGatewayPresenceLimited;
    }
    if (!hasMessageContent) {
      patchFlags |= _applicationFlagGatewayMessageContentLimited;
    }

    if (patchFlags == flags) {
      return PortalPrivilegedIntentSyncResult(enabled: enabled);
    }

    final patchResponse = await httpClient.patch(
      Uri.parse('$_discordApiBase/applications/@me'),
      headers: {
        'Authorization': 'Bot $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'flags': patchFlags}),
    );

    if (patchResponse.statusCode == 401) {
      throw DiscordTokenUnauthorizedException(
        'Failed to update application flags via PATCH '
        '(${patchResponse.statusCode})',
      );
    }

    if (patchResponse.statusCode < 200 || patchResponse.statusCode >= 300) {
      throw PortalIntentPatchFailedException(patchResponse.statusCode);
    }

    enabled = {...enabled, ...privilegedIntentKeys};
    return PortalPrivilegedIntentSyncResult(
      enabled: enabled,
      didAutoEnable: true,
    );
  } finally {
    if (ownsClient) {
      httpClient.close();
    }
  }
}

Future<int> _fetchApplicationFlags(
  String token, {
  required http.Client client,
}) async {
  final response = await client.get(
    Uri.parse('$_discordApiBase/applications/@me'),
    headers: {'Authorization': 'Bot $token'},
  );

  if (response.statusCode == 401 || response.statusCode == 403) {
    throw DiscordTokenUnauthorizedException(
      'Failed to fetch application flags (${response.statusCode})',
    );
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Failed to fetch application flags (${response.statusCode})',
    );
  }

  final body = jsonDecode(response.body);
  if (body is! Map) {
    throw Exception('Invalid application response from Discord API');
  }

  final flags = body['flags'];
  return flags is int ? flags : int.tryParse(flags?.toString() ?? '') ?? 0;
}

Future<int> _fetchUserFlags(
  String token, {
  required http.Client client,
}) async {
  final response = await client.get(
    Uri.parse('$_discordApiBase/users/@me'),
    headers: {'Authorization': 'Bot $token'},
  );

  if (response.statusCode == 401 || response.statusCode == 403) {
    throw DiscordTokenUnauthorizedException(
      'Failed to fetch user info (${response.statusCode})',
    );
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Failed to fetch user info (${response.statusCode})');
  }

  final body = jsonDecode(response.body);
  if (body is! Map) {
    throw Exception('Invalid user response from Discord API');
  }

  final flags = body['flags'];
  return flags is int ? flags : int.tryParse(flags?.toString() ?? '') ?? 0;
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
