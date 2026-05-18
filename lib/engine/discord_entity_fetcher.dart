import 'dart:async';
import 'package:nyxx/nyxx.dart';
import '../utils/global.dart';

class DiscordEntityFetcher {
  static Future<void> hydrateEntity(
    NyxxGateway gateway,
    String scope,
    String contextId,
    Map<String, String> variables,
  ) async {
    final id = _parseSnowflake(contextId);
    if (id == null) return;

    try {
      switch (scope) {
        case 'user':
          final user = await gateway.users.fetch(id);
          _populateUserVariables(variables, contextId, user);
          break;

        case 'member':
          final guildId = _resolveGuildId(variables);
          if (guildId == null) return;

          final member = await gateway.guilds[guildId].members.fetch(id);
          _populateMemberVariables(variables, contextId, member);
          if (member.user != null) {
            _populateUserVariables(variables, contextId, member.user!);
          }
          break;

        case 'channel':
          final channel = await gateway.channels.fetch(id);
          variables[_key('channel', contextId, 'name')] = _getChannelName(channel);
          variables[_key('channel', contextId, 'id')] = channel.id.toString();
          break;

        case 'guild':
          final guild = await gateway.guilds.fetch(id);
          variables[_key('guild', contextId, 'name')] = guild.name;
          variables[_key('guild', contextId, 'id')] = guild.id.toString();
          variables[_key('guild', contextId, 'memberCount')] =
              guild.approximateMemberCount?.toString() ?? '0';
          break;

        default:
          break;
      }
    } catch (e, st) {
      // Replace with your project's logger if available
      print('Error while hydrating $scope id=$contextId: $e\n$st');
      rethrow;
    }
  }

  // Helpers

  static Snowflake? _parseSnowflake(String idStr) {
    final parsed = int.tryParse(idStr);
    return parsed != null ? Snowflake(parsed) : null;
  }

  static Snowflake? _resolveGuildId(Map<String, String> variables) {
    final guildIdStr =
        variables['guild.id'] ?? variables['interaction.guildId'] ?? variables['guildId'];
    final parsed = int.tryParse(guildIdStr ?? '');
    return parsed != null ? Snowflake(parsed) : null;
  }

  static String _key(String scope, String contextId, String field) =>
      '$scope[$contextId].$field';

  static void _populateUserVariables(
    Map<String, String> variables,
    String contextId,
    User user,
  ) {
    variables[_key('user', contextId, 'username')] = user.username;
    variables[_key('user', contextId, 'tag')] = user.discriminator;
    variables[_key('user', contextId, 'avatar')] = _safeAvatarUrl(
      id: user.id.toString(),
      avatar: user.avatar,
      discriminator: user.discriminator,
    );
    variables[_key('user', contextId, 'globalName')] = user.globalName ?? user.username;
    variables[_key('user', contextId, 'displayName')] = user.globalName ?? user.username;
    variables[_key('user', contextId, 'createdAt')] =
        user.id.timestamp.toIso8601String();
  }

  // Using dynamic to avoid type issues across different library versions
  static void _populateMemberVariables(
    Map<String, String> variables,
    String contextId,
    dynamic member,
  ) {
    variables[_key('member', contextId, 'nick')] = member.nick ?? '';
    variables[_key('member', contextId, 'avatar')] = _safeAvatarUrl(
      id: member.id.toString(),
      avatar: member.avatar ?? member.user?.avatar,
      discriminator: member.user?.discriminator,
    );
    variables[_key('member', contextId, 'displayName')] =
        member.nick ?? member.user?.globalName ?? member.user?.username ?? '';
    variables[_key('member', contextId, 'joinedAt')] =
        member.joinedAt?.toIso8601String() ?? '';
    variables[_key('member', contextId, 'roles')] =
        (member.roleIds ?? []).map((rid) => rid.toString()).join(',');
  }

  // Avatar structure may vary across library versions; using dynamic for safety
  static String _safeAvatarUrl({
    required String id,
    dynamic avatar,
    String? discriminator,
  }) {
    if (avatar == null) return '';
    final avatarHash = avatar.hash;
    final isAnimated = avatar.isAnimated ?? false;
    return makeAvatarUrl(
      id,
      avatarId: avatarHash,
      isAnimated: isAnimated,
      legacyFormat: 'webp',
      discriminator: discriminator,
    );
  }

  static String _getChannelName(Channel channel) {
    if (channel is GuildTextChannel ||
        channel is GuildVoiceChannel ||
        channel is ThreadsOnlyChannel ||
        channel is GuildStageChannel) {
      return (channel as dynamic).name ?? 'Unknown Channel';
    }
    if (channel is DmChannel) return 'DM';
    return 'Unknown Channel';
  }
}
