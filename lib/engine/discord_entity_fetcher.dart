import 'dart:async';
import 'package:nyxx/nyxx.dart';
import '../utils/global.dart';

/// Logic to hydrate Discord entities (user, member, channel, guild) into runtime variables.
class DiscordEntityFetcher {
  /// Hydrates a specific Discord entity into the [variables] map.
  static Future<void> hydrateEntity(
    NyxxGateway gateway,
    String scope,
    String contextId,
    Map<String, String> variables,
  ) async {
    final id =
        int.tryParse(contextId) != null ? Snowflake(int.parse(contextId)) : null;
    if (id == null) return;

    try {
      switch (scope) {
        case 'user':
          final user = await gateway.users.fetch(id);
          variables['user[$contextId].username'] = user.username;
          variables['user[$contextId].tag'] = user.discriminator;
          variables['user[$contextId].avatar'] = makeAvatarUrl(
            user.id.toString(),
            avatarId: user.avatar.hash,
            isAnimated: user.avatar.isAnimated,
            legacyFormat: 'webp',
            discriminator: user.discriminator,
          );
          variables['user[$contextId].globalName'] =
              user.globalName ?? user.username;
          variables['user[$contextId].displayName'] =
              user.globalName ?? user.username;
          variables['user[$contextId].createdAt'] =
              user.id.timestamp.toIso8601String();
          break;
        case 'member':
          final guildIdStr =
              variables['guild.id'] ??
              variables['interaction.guildId'] ??
              variables['guildId'];
          final parsedGuildId = int.tryParse(guildIdStr ?? '');
          final guildId =
              parsedGuildId != null ? Snowflake(parsedGuildId) : null;
          if (guildId != null) {
            final member = await gateway.guilds[guildId].members.fetch(id);
            variables['member[$contextId].nick'] = member.nick ?? '';
            variables['member[$contextId].avatar'] = makeAvatarUrl(
              member.id.toString(),
              avatarId: member.avatar?.hash,
              isAnimated: member.avatar?.isAnimated ?? false,
              legacyFormat: 'webp',
              discriminator: member.user?.discriminator,
            );
            variables['member[$contextId].displayName'] =
                member.nick ?? member.user?.globalName ?? member.user?.username ?? '';
            variables['member[$contextId].joinedAt'] =
                member.joinedAt.toIso8601String();
            variables['member[$contextId].roles'] = member.roleIds
                .map((rid) => rid.toString())
                .join(',');

            final user = member.user;
            if (user != null) {
              variables['user[$contextId].username'] = user.username;
              variables['user[$contextId].tag'] = user.discriminator;
              variables['user[$contextId].avatar'] = makeAvatarUrl(
                user.id.toString(),
                avatarId: user.avatar.hash,
                isAnimated: user.avatar.isAnimated,
                legacyFormat: 'webp',
                discriminator: user.discriminator,
              );
              variables['user[$contextId].globalName'] =
                  user.globalName ?? user.username;
            }
          }
          break;
        case 'channel':
          final channel = await gateway.channels.fetch(id);
          variables['channel[$contextId].name'] = getChannelName(channel);
          variables['channel[$contextId].id'] = channel.id.toString();
          break;
        case 'guild':
          final guild = await gateway.guilds.fetch(id);
          variables['guild[$contextId].name'] = guild.name;
          variables['guild[$contextId].id'] = guild.id.toString();
          variables['guild[$contextId].memberCount'] =
              guild.approximateMemberCount?.toString() ?? '0';
          break;
      }
    } catch (_) {}
  }

  static String getChannelName(Channel channel) {
    if (channel is GuildTextChannel) {
      return channel.name;
    }
    if (channel is GuildVoiceChannel) {
      return channel.name;
    }
    if (channel is ThreadsOnlyChannel) {
      return channel.name;
    }
    if (channel is GuildStageChannel) {
      return channel.name;
    }
    if (channel is DmChannel) {
      return 'DM';
    }
    return 'Unknown Channel';
  }
}
