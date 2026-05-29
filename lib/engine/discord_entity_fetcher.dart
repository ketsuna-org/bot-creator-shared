import 'dart:async';
import 'package:nyxx/nyxx.dart';
import '../utils/global.dart';

class DiscordEntityFetcher {
  /// Deduplicates in-flight requests across all instances to prevent race conditions
  /// and redundant network calls for the same entity in the same batch.
  static final Map<String, Future<void>> _inFlight = {};

  static Future<void> hydrateEntity(
    NyxxGateway gateway,
    String scope,
    String contextId,
    Map<String, String> variables, {
    Map<String, dynamic>? cache,
  }) async {
    final id = _parseSnowflake(contextId);
    if (id == null) return;

    final flightKey = '$scope:$contextId';

    // Check if we already have this entity in our session cache
    if (cache != null && cache.containsKey(flightKey)) {
      final cached = cache[flightKey];
      if (cached is User) {
        _populateUserVariables(variables, contextId, cached);
      } else if (cached is Member) {
        _populateMemberVariables(variables, contextId, cached);
        if (cached.user != null) {
          _populateUserVariables(variables, contextId, cached.user!);
        }
      } else if (cached is Channel) {
        variables[_key('channel', contextId, 'name')] = _getChannelName(cached);
        variables[_key('channel', contextId, 'id')] = cached.id.toString();
      } else if (cached is Guild) {
        variables[_key('guild', contextId, 'name')] = cached.name;
        variables[_key('guild', contextId, 'id')] = cached.id.toString();
        variables[_key('guild', contextId, 'memberCount')] =
            cached.approximateMemberCount?.toString() ?? '0';
      } else if (cached is Role) {
        _populateRoleVariables(variables, contextId, cached);
      } else if (cached is Message) {
        _populateMessageVariables(variables, contextId, cached);
      }
      return;
    }

    // Deduplicate in-flight requests
    if (_inFlight.containsKey(flightKey)) {
      await _inFlight[flightKey];
      // After the other flight finishes, the variables should be populated.
      // We still want to return to avoid re-fetching.
      return;
    }

    final completer = Completer<void>();
    _inFlight[flightKey] = completer.future;

    try {
      dynamic fetchedEntity;

      switch (scope) {
        case 'user':
          final user = await gateway.users.fetch(id);
          fetchedEntity = user;
          _populateUserVariables(variables, contextId, user);
          break;

        case 'member':
          final guildId = _resolveGuildId(variables);
          if (guildId == null) {
            final user = await gateway.users.fetch(id);
            fetchedEntity = user;
            _populateUserVariables(variables, contextId, user);
            break;
          }

          final member = await gateway.guilds[guildId].members.fetch(id);
          fetchedEntity = member;
          _populateMemberVariables(variables, contextId, member);
          if (member.user != null) {
            _populateUserVariables(variables, contextId, member.user!);
          }
          break;

        case 'channel':
          final channel = await gateway.channels.fetch(id);
          fetchedEntity = channel;
          variables[_key('channel', contextId, 'name')] = _getChannelName(
            channel,
          );
          variables[_key('channel', contextId, 'id')] = channel.id.toString();
          break;

        case 'guild':
          final guild = await gateway.guilds.fetch(id);
          fetchedEntity = guild;
          variables[_key('guild', contextId, 'name')] = guild.name;
          variables[_key('guild', contextId, 'id')] = guild.id.toString();
          variables[_key('guild', contextId, 'memberCount')] =
              guild.approximateMemberCount?.toString() ?? '0';
          break;

        case 'role':
          final guildId = _resolveGuildId(variables);
          if (guildId != null) {
            final role = await gateway.guilds[guildId].roles.fetch(id);
            fetchedEntity = role;
            _populateRoleVariables(variables, contextId, role);
          }
          break;

        case 'message':
          final channelId = _resolveChannelId(variables);
          if (channelId != null) {
            final message = await (gateway.channels[channelId] as dynamic)
                .messages
                .fetch(id);
            fetchedEntity = message;
            _populateMessageVariables(variables, contextId, message);
          }
          break;

        default:
          break;
      }

      if (cache != null && fetchedEntity != null) {
        cache[flightKey] = fetchedEntity;
      }

      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _inFlight.remove(flightKey);
    }
  }

  // Helpers

  static Snowflake? _parseSnowflake(String idStr) {
    final parsed = int.tryParse(idStr);
    return parsed != null ? Snowflake(parsed) : null;
  }

  static Snowflake? _resolveGuildId(Map<String, String> variables) {
    final guildIdStr =
        variables['guild.id'] ??
        variables['interaction.guildId'] ??
        variables['guildId'];
    final parsed = int.tryParse(guildIdStr ?? '');
    return parsed != null ? Snowflake(parsed) : null;
  }

  static Snowflake? _resolveChannelId(Map<String, String> variables) {
    final channelIdStr =
        variables['channel.id'] ??
        variables['interaction.channelId'] ??
        variables['channelId'];
    final parsed = int.tryParse(channelIdStr ?? '');
    return parsed != null ? Snowflake(parsed) : null;
  }

  static String _key(String scope, String contextId, String field) =>
      '$scope[$contextId].$field';

  static void _populateUserVariables(
    Map<String, String> variables,
    String contextId,
    User user,
  ) {
    final keys = <String>[];
    void set(String field, String value) {
      final key = _key('user', contextId, field);
      variables[key] = value;
      keys.add(key);
    }

    set('username', user.username);
    set('tag', user.discriminator);
    set(
      'avatar',
      _safeAvatarUrl(
        id: user.id.toString(),
        avatar: user.avatar,
        discriminator: user.discriminator,
      ),
    );
    set('globalName', user.globalName ?? user.username);
    set('displayName', user.globalName ?? user.username);
    set('createdAt', user.id.timestamp.toIso8601String());
    set('isBot', user.isBot.toString());
  }

  // Using dynamic to avoid type issues across different library versions
  static void _populateMemberVariables(
    Map<String, String> variables,
    String contextId,
    dynamic member,
  ) {
    final keys = <String>[];
    void set(String field, String value) {
      final key = _key('member', contextId, field);
      variables[key] = value;
      keys.add(key);
    }

    set('nick', member.nick ?? '');
    set(
      'avatar',
      _safeAvatarUrl(
        id: member.id.toString(),
        avatar: member.avatar ?? member.user?.avatar,
        discriminator: member.user?.discriminator,
      ),
    );
    set(
      'displayName',
      member.nick ?? member.user?.globalName ?? member.user?.username ?? '',
    );
    set('joinedAt', member.joinedAt?.toIso8601String() ?? '');
    set('roles', (member.roleIds ?? []).map((rid) => rid.toString()).join(','));
  }

  static void _populateRoleVariables(
    Map<String, String> variables,
    String contextId,
    Role role,
  ) {
    variables[_key('role', contextId, 'name')] = role.name;
    variables[_key('role', contextId, 'id')] = role.id.toString();
    variables[_key('role', contextId, 'color')] = role.colors.primary.value
        .toRadixString(16);
    variables[_key('role', contextId, 'position')] = role.position.toString();
    variables[_key('role', contextId, 'mentionable')] =
        role.isMentionable.toString();
    variables[_key('role', contextId, 'hoist')] = role.isHoisted.toString();
    variables[_key('role', contextId, 'permissions')] =
        role.permissions.value.toString();
  }

  static void _populateMessageVariables(
    Map<String, String> variables,
    String contextId,
    Message message,
  ) {
    variables[_key('message', contextId, 'content')] = message.content;
    variables[_key('message', contextId, 'id')] = message.id.toString();
    variables[_key('message', contextId, 'authorId')] =
        message.author.id.toString();
    variables[_key('message', contextId, 'channelId')] =
        message.channelId.toString();
    variables[_key('message', contextId, 'createdAt')] =
        message.timestamp.toIso8601String();
  }

  // Avatar structure may vary across library versions; using dynamic for safety
  static String _safeAvatarUrl({
    required String id,
    dynamic avatar,
    String? discriminator,
  }) {
    if (avatar == null) {
      return makeAvatarUrl(
        id,
        avatarId: null,
        discriminator: discriminator,
      );
    }
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
