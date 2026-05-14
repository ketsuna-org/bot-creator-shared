import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';

// ── Permission cache ─────────────────────────────────────────────────────────

/// Caches guild and bot-member data for the lifetime of a single command
/// execution so that repeated permission checks don't make redundant HTTP
/// calls.
class BotPermissionCache {
  Guild? _guild;
  Snowflake? _cachedGuildId;
  Permissions? _botPermissions;
  Member? _botMember;

  Future<Guild> getGuild(NyxxGateway client, Snowflake guildId) async {
    if (_guild != null && _cachedGuildId == guildId) return _guild!;
    _cachedGuildId = guildId;
    _guild = await fetchGuildCached(client, guildId);
    _botPermissions = null;
    _botMember = null;
    return _guild!;
  }

  Future<Permissions> getBotPermissions(
    NyxxGateway client,
    Guild guild,
    Snowflake guildId,
  ) async {
    if (_botPermissions != null && _cachedGuildId == guildId) {
      return _botPermissions!;
    }
    final member = await _fetchBotMember(client, guild);
    _botPermissions = _permissionsFromRoles(guild, member.roleIds, guildId);
    return _botPermissions!;
  }

  Future<Member> _fetchBotMember(NyxxGateway client, Guild guild) async {
    if (_botMember != null && _cachedGuildId == guild.id) return _botMember!;
    _botMember = await guild.members.get(client.user.id);
    return _botMember!;
  }

  Future<Member> getBotMember(NyxxGateway client, Guild guild) =>
      _fetchBotMember(client, guild);
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Computes the combined permissions of the bot in [guild] by merging the
/// permissions of each of its roles (+ the @everyone role).
Future<Permissions> _computeBotPermissions(
  NyxxGateway client,
  Guild guild,
  Snowflake guildId,
) async {
  final botMember = await guild.members.get(client.user.id);
  return _permissionsFromRoles(guild, botMember.roleIds, guildId);
}

Permissions _permissionsFromRoles(
  Guild guild,
  List<Snowflake> roleIds,
  Snowflake guildId,
) {
  return Permissions(
    guild.roleList
        .where((r) => roleIds.contains(r.id) || r.id == guildId)
        .fold<int>(0, (acc, r) => acc | r.permissions.value),
  );
}

// ── Simple permission check (no role hierarchy) ─────────────────────────────

/// Checks that the bot has **all** of the given [requiredPermissions] in
/// the guild identified by [guildId].
///
/// Returns an error string if any permission is missing, or `null` if the
/// bot is authorised.
Future<String?> checkBotGuildPermission(
  NyxxGateway client, {
  required Snowflake guildId,
  required List<Flag<Permissions>> requiredPermissions,
  required String actionLabel,
  BotPermissionCache? cache,
}) async {
  final guild =
      cache != null
          ? await cache.getGuild(client, guildId)
          : await fetchGuildCached(client, guildId);
  if (guild == null) return 'Guild not found';
  final perms =
      cache != null
          ? await cache.getBotPermissions(client, guild, guildId)
          : await _computeBotPermissions(client, guild, guildId);

  if (perms.isAdministrator) return null;

  final missing = <String>[];
  for (final perm in requiredPermissions) {
    if (!perms.has(perm)) {
      missing.add(_permissionName(perm));
    }
  }

  if (missing.isEmpty) return null;
  return 'I do not have permission to $actionLabel. '
      'Missing: ${missing.join(', ')}.';
}

// ── Moderation check (permissions + role hierarchy) ─────────────────────────

/// Checks whether the bot can moderate [targetUserId] in the given guild.
///
/// Returns an error string if the action should be blocked, or `null` if
/// the bot is authorised to proceed.
///
/// Checks performed:
/// 1. Bot has the required [requiredPermission] (e.g. ban/kick/moderate).
/// 2. Target is not the guild owner.
/// 3. Bot's highest role is above the target's highest role.
Future<String?> checkBotCanModerate(
  NyxxGateway client, {
  required Snowflake guildId,
  required Snowflake targetUserId,
  required Flag<Permissions> requiredPermission,
  required String actionLabel,
  BotPermissionCache? cache,
}) async {
  final guild =
      cache != null
          ? await cache.getGuild(client, guildId)
          : await fetchGuildCached(client, guildId);
  if (guild == null) return 'Guild not found';

  // ── 1. Check bot permissions ──
  final botMember =
      cache != null
          ? await cache.getBotMember(client, guild)
          : await guild.members.get(client.user.id);
  final botRoleIds = botMember.roleIds;
  final botPermissions = _permissionsFromRoles(guild, botRoleIds, guildId);

  if (!botPermissions.isAdministrator &&
      !botPermissions.has(requiredPermission)) {
    return 'I do not have permission to $actionLabel.';
  }

  // ── 2. Cannot target the guild owner ──
  if (targetUserId == guild.ownerId) {
    return 'I cannot $actionLabel the server owner.';
  }

  // ── 3. Role hierarchy: bot's highest role must be above target's ──
  final targetMember = await guild.members.get(targetUserId);
  final targetRoleIds = targetMember.roleIds;

  int highestPosition(List<Snowflake> roleIds) {
    var max = 0;
    for (final role in guild.roleList) {
      if (roleIds.contains(role.id) && role.position > max) {
        max = role.position;
      }
    }
    return max;
  }

  final botHighest = highestPosition(botRoleIds);
  final targetHighest = highestPosition(targetRoleIds);

  if (botHighest <= targetHighest) {
    return 'I cannot $actionLabel this user: their highest role is equal to or above mine.';
  }

  return null;
}

// ── Human-readable permission names ─────────────────────────────────────────

String _permissionName(Flag<Permissions> flag) {
  final map = <int, String>{
    Permissions.addReactions.value: 'Add Reactions',
    Permissions.administrator.value: 'Administrator',
    Permissions.banMembers.value: 'Ban Members',
    Permissions.createInstantInvite.value: 'Create Instant Invite',
    Permissions.createPublicThreads.value: 'Create Public Threads',
    Permissions.createPrivateThreads.value: 'Create Private Threads',
    Permissions.kickMembers.value: 'Kick Members',
    Permissions.manageChannels.value: 'Manage Channels',
    Permissions.manageGuild.value: 'Manage Server',
    Permissions.manageMessages.value: 'Manage Messages',
    Permissions.manageRoles.value: 'Manage Roles',
    Permissions.manageWebhooks.value: 'Manage Webhooks',
    Permissions.moderateMembers.value: 'Moderate Members',
    Permissions.moveMembers.value: 'Move Members',
    Permissions.muteMembers.value: 'Mute Members',
    Permissions.deafenMembers.value: 'Deafen Members',
    Permissions.readMessageHistory.value: 'Read Message History',
    Permissions.sendMessages.value: 'Send Messages',
    Permissions.manageGuildExpressions.value: 'Manage Expressions',
  };
  return map[flag.value] ?? 'Permission(${flag.value})';
}
