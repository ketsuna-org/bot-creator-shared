import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'permission_checks.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return Snowflake(parsed);
}

bool _parseBool(dynamic value, {bool defaultValue = false}) {
  final raw = value?.toString().toLowerCase().trim() ?? '';
  if (raw == 'true' || raw == '1' || raw == 'yes') return true;
  if (raw == 'false' || raw == '0' || raw == 'no') return false;
  return defaultValue;
}

/// Moves a member to a voice channel.
///
/// Payload fields:
/// - `userId` — member to move (required)
/// - `targetChannelId` — destination voice channel (required)
/// - `reason` — audit log reason
///
/// Returns `{'userId', 'channelId', 'status': 'moved'}` or `{'error': '...'}`.
Future<Map<String, String>> moveToVoiceChannelAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'moveToVoiceChannel requires a guild context'};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.moveMembers],
      actionLabel: 'move members in voice channels',
    );
    if (permError != null) {
      return {'error': permError};
    }

    final userId = _toSnowflake(resolve((payload['userId'] ?? '').toString()));
    if (userId == null) {
      return {'error': 'userId is required for moveToVoiceChannel'};
    }
    final targetChannelId = _toSnowflake(
      resolve((payload['targetChannelId'] ?? '').toString()),
    );
    if (targetChannelId == null) {
      return {'error': 'targetChannelId is required for moveToVoiceChannel'};
    }
    final reason = resolve((payload['reason'] ?? '').toString()).trim();

    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found'};
    await guild.members.update(
      userId,
      MemberUpdateBuilder(voiceChannelId: targetChannelId),
      auditLogReason: reason.isNotEmpty ? reason : null,
    );

    return {
      'userId': userId.toString(),
      'channelId': targetChannelId.toString(),
      'status': 'moved',
    };
  } catch (e) {
    return {'error': 'Failed to move member to voice channel: $e'};
  }
}

/// Disconnects a member from their current voice channel.
///
/// Payload fields:
/// - `userId` — member to disconnect (required)
/// - `reason` — audit log reason
///
/// Returns `{'userId', 'status': 'disconnected'}` or `{'error': '...'}`.
Future<Map<String, String>> disconnectFromVoiceAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'disconnectFromVoice requires a guild context'};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.moveMembers],
      actionLabel: 'disconnect members from voice',
    );
    if (permError != null) {
      return {'error': permError};
    }

    final userId = _toSnowflake(resolve((payload['userId'] ?? '').toString()));
    if (userId == null) {
      return {'error': 'userId is required for disconnectFromVoice'};
    }
    final reason = resolve((payload['reason'] ?? '').toString()).trim();

    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found'};
    await guild.members.update(
      userId,
      MemberUpdateBuilder(voiceChannelId: Snowflake.zero),
      auditLogReason: reason.isNotEmpty ? reason : null,
    );

    return {'userId': userId.toString(), 'status': 'disconnected'};
  } catch (e) {
    return {'error': 'Failed to disconnect member from voice: $e'};
  }
}

/// Server-mutes or unmutes a guild member.
///
/// Payload fields:
/// - `userId` — member to (un)mute (required)
/// - `mute` — true to mute, false to unmute (required)
/// - `reason` — audit log reason
///
/// Returns `{'userId', 'status': 'muted' | 'unmuted'}` or `{'error': '...'}`.
Future<Map<String, String>> serverMuteMemberAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'serverMuteMember requires a guild context'};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.muteMembers],
      actionLabel: 'server-mute members',
    );
    if (permError != null) {
      return {'error': permError};
    }

    final userId = _toSnowflake(resolve((payload['userId'] ?? '').toString()));
    if (userId == null) {
      return {'error': 'userId is required for serverMuteMember'};
    }
    final mute = _parseBool(resolve((payload['mute'] ?? 'true').toString()));
    final reason = resolve((payload['reason'] ?? '').toString()).trim();

    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found'};
    await guild.members.update(
      userId,
      MemberUpdateBuilder(isMute: mute),
      auditLogReason: reason.isNotEmpty ? reason : null,
    );

    return {'userId': userId.toString(), 'status': mute ? 'muted' : 'unmuted'};
  } catch (e) {
    return {'error': 'Failed to server-mute member: $e'};
  }
}

/// Server-deafens or undeafens a guild member.
///
/// Payload fields:
/// - `userId` — member to (un)deafen (required)
/// - `deaf` — true to deafen, false to undeafen (required)
/// - `reason` — audit log reason
///
/// Returns `{'userId', 'status': 'deafened' | 'undeafened'}` or `{'error': '...'}`.
Future<Map<String, String>> serverDeafenMemberAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'serverDeafenMember requires a guild context'};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.deafenMembers],
      actionLabel: 'server-deafen members',
    );
    if (permError != null) {
      return {'error': permError};
    }

    final userId = _toSnowflake(resolve((payload['userId'] ?? '').toString()));
    if (userId == null) {
      return {'error': 'userId is required for serverDeafenMember'};
    }
    final deaf = _parseBool(resolve((payload['deaf'] ?? 'true').toString()));
    final reason = resolve((payload['reason'] ?? '').toString()).trim();

    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found'};
    await guild.members.update(
      userId,
      MemberUpdateBuilder(isDeaf: deaf),
      auditLogReason: reason.isNotEmpty ? reason : null,
    );

    return {
      'userId': userId.toString(),
      'status': deaf ? 'deafened' : 'undeafened',
    };
  } catch (e) {
    return {'error': 'Failed to server-deafen member: $e'};
  }
}
