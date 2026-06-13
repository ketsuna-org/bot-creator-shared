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
    if (id == null &&
        scope != 'getMessage' &&
        scope != 'getmessage' &&
        scope != 'getReactions' &&
        scope != 'getreactions' &&
        scope != 'emoji') {
      return;
    }

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
        _populateGuildVariables(variables, contextId, cached);
      } else if (cached is Role) {
        _populateRoleVariables(variables, contextId, cached);
      } else if (cached is Message) {
        if (scope == 'getMessage' || scope == 'getmessage') {
          final parts = contextId.split(';');
          if (parts.length == 2) {
            _populateGetMessageVariables(variables, parts[0], parts[1], cached);
          }
        } else if (scope == 'getReactions' || scope == 'getreactions') {
          final parts = contextId.split(';');
          if (parts.length == 3) {
            _populateGetReactionsVariables(variables, parts[0], parts[1], parts[2], cached);
          }
        } else {
          _populateMessageVariables(variables, contextId, cached);
        }
      } else if (cached is Emoji) {
        _populateEmojiVariables(variables, contextId, cached);
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
          final user = await gateway.users.fetch(id!);
          fetchedEntity = user;
          _populateUserVariables(variables, contextId, user);
          break;

        case 'member':
          final guildId = _resolveGuildId(variables);
          if (guildId == null) {
            final user = await gateway.users.fetch(id!);
            fetchedEntity = user;
            _populateUserVariables(variables, contextId, user);
            break;
          }

          final member = await gateway.guilds[guildId].members.fetch(id!);
          fetchedEntity = member;
          final guild = await gateway.guilds[guildId].get();
          _populateMemberVariables(variables, contextId, member,
              guild: guild);
          if (member.user != null) {
            _populateUserVariables(variables, contextId, member.user!);
          }
          break;

        case 'channel':
          final channel = await gateway.channels.fetch(id!);
          fetchedEntity = channel;
          variables[_key('channel', contextId, 'name')] = _getChannelName(
            channel,
          );
          variables[_key('channel', contextId, 'id')] = channel.id.toString();
          break;

        case 'guild':
          final guild = await gateway.guilds.fetch(id!);
          fetchedEntity = guild;
          _populateGuildVariables(variables, contextId, guild);
          break;

        case 'role':
          final guildId = _resolveGuildId(variables);
          if (guildId != null) {
            final role = await gateway.guilds[guildId].roles.fetch(id!);
            fetchedEntity = role;
            _populateRoleVariables(variables, contextId, role);
          }
          break;

        case 'message':
          final channelId = _resolveChannelId(variables);
          if (channelId != null) {
            final message = await (gateway.channels[channelId] as dynamic)
                .messages
                .fetch(id!);
            fetchedEntity = message;
            _populateMessageVariables(variables, contextId, message);
          }
          break;

        case 'getMessage':
        case 'getmessage':
          final parts = contextId.split(';');
          if (parts.length == 2) {
            final chanId = _parseSnowflake(parts[0]);
            final msgId = _parseSnowflake(parts[1]);
            if (chanId != null && msgId != null) {
              final message = await (gateway.channels[chanId] as dynamic)
                  .messages
                  .fetch(msgId);
              fetchedEntity = message;
              _populateGetMessageVariables(variables, parts[0], parts[1], message);
            }
          }
          break;

        case 'getReactions':
        case 'getreactions':
          final parts = contextId.split(';');
          if (parts.length == 3) {
            final chanId = _parseSnowflake(parts[0]);
            final msgId = _parseSnowflake(parts[1]);
            final emoji = parts[2];
            if (chanId != null && msgId != null) {
              final message = await (gateway.channels[chanId] as dynamic)
                  .messages
                  .fetch(msgId);
              fetchedEntity = message;
              _populateGetReactionsVariables(variables, parts[0], parts[1], emoji, message);
            }
          }
          break;

        case 'emoji':
          final guildId = _resolveGuildId(variables);
          Emoji? foundEmoji;
          if (guildId != null) {
            try {
              final guild = await gateway.guilds[guildId].get();
              for (final emoji in guild.emojis.cache.values) {
                if (emoji.id.toString() == contextId || emoji.name == contextId) {
                  foundEmoji = emoji;
                  break;
                }
              }
            } catch (_) {}
          }
          if (foundEmoji == null) {
            for (final guild in gateway.guilds.cache.values) {
              for (final emoji in guild.emojis.cache.values) {
                if (emoji.id.toString() == contextId || emoji.name == contextId) {
                  foundEmoji = emoji;
                  break;
                }
              }
              if (foundEmoji != null) break;
            }
          }
          if (foundEmoji != null) {
            fetchedEntity = foundEmoji;
            _populateEmojiVariables(variables, contextId, foundEmoji);
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
    dynamic member, {
    dynamic guild,
  }) {
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

    // Compute highest/lowest role by position from guild role list
    if (guild != null) {
      try {
        final memberRoleIds = <String>{};
        final roleIdsRaw = member.roleIds;
        if (roleIdsRaw is Iterable) {
          for (final rid in roleIdsRaw) {
            memberRoleIds.add(rid.toString().trim());
          }
        }

        final roleListRaw = guild.roleList;
        if (roleListRaw is Iterable) {
          String? highestRoleId;
          int highestPos = -1;
          String? lowestRoleId;
          int lowestPos = 999999;

          for (final role in roleListRaw) {
            final roleId = role.id.toString().trim();
            if (!memberRoleIds.contains(roleId)) continue;
            final pos = (role.position as int?) ?? 0;

            // Skip @everyone role (position <= 0)
            if (pos <= 0) continue;

            if (pos > highestPos) {
              highestPos = pos;
              highestRoleId = roleId;
            }
            if (pos < lowestPos) {
              lowestPos = pos;
              lowestRoleId = roleId;
            }
          }

          if (highestRoleId != null) {
            set('highestRole', highestRoleId);
            set('highestRoleWithPerms', highestRoleId);
          }
          if (lowestRoleId != null) {
            set('lowestRole', lowestRoleId);
            set('lowestRoleWithPerms', lowestRoleId);
          }
        }
      } catch (_) {
        // Role position not available — skip silently
      }
    }
  }

  static void _populateGuildVariables(
    Map<String, String> variables,
    String contextId,
    Guild guild,
  ) {
    variables[_key('guild', contextId, 'name')] = guild.name;
    variables[_key('guild', contextId, 'id')] = guild.id.toString();
    variables[_key('guild', contextId, 'memberCount')] =
        guild.approximateMemberCount?.toString() ?? '0';
    variables[_key('guild', contextId, 'premiumSubscriptionCount')] =
        guild.premiumSubscriptionCount?.toString() ?? '0';
    variables[_key('guild', contextId, 'premiumTier')] =
        guild.premiumTier.toString();
    variables[_key('guild', contextId, 'emojiCount')] =
        guild.emojis.cache.length.toString();
    variables[_key('guild', contextId, 'stickerCount')] =
        guild.stickers.cache.length.toString();
    variables[_key('guild', contextId, 'exists')] = 'true';
    variables[_key('guild', contextId, 'description')] =
        guild.description ?? '';
    variables[_key('guild', contextId, 'ownerId')] =
        guild.ownerId.toString();
    variables[_key('guild', contextId, 'verificationLevel')] =
        guild.verificationLevel.value.toString();
    variables[_key('guild', contextId, 'features')] =
        guild.features.join(',');
    variables[_key('guild', contextId, 'vanityUrlCode')] =
        guild.vanityUrlCode ?? '';
    variables[_key('guild', contextId, 'banner')] =
        guild.banner?.toString() ?? '';
    variables[_key('guild', contextId, 'splash')] =
        guild.splash?.toString() ?? '';
    variables[_key('guild', contextId, 'afkTimeout')] =
        guild.afkTimeout.inSeconds.toString();
    variables[_key('guild', contextId, 'preferredLocale')] =
        guild.preferredLocale.toString();
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

  static void _populateGetMessageVariables(
    Map<String, String> variables,
    String channelId,
    String messageId,
    Message message,
  ) {
    final prefix = 'getMessage[$channelId;$messageId]';
    variables['$prefix.content'] = message.content;
    variables['$prefix.id'] = message.id.toString();
    variables['$prefix.authorId'] = message.author.id.toString();
    variables['$prefix.channelId'] = message.channelId.toString();
    variables['$prefix.createdAt'] = message.timestamp.toIso8601String();
    variables['$prefix.author'] = message.author.username;
  }

  static void _populateGetReactionsVariables(
    Map<String, String> variables,
    String channelId,
    String messageId,
    String emoji,
    Message message,
  ) {
    final key = 'getReactions[$channelId;$messageId;$emoji]';
    final rx = message.reactions;
    if (rx.isEmpty) {
      variables[key] = '0';
      return;
    }
    for (final r in rx) {
      final emojiObj = r.emoji;
      final name = emojiObj is Emoji ? (emojiObj.name ?? '') : '';
      final id = emojiObj.id.toString();
      if (name == emoji || id == emoji || '$name:$id' == emoji) {
        variables[key] = r.count.toString();
        return;
      }
    }
    variables[key] = '0';
  }

  static void _populateEmojiVariables(
    Map<String, String> variables,
    String contextId,
    Emoji emoji,
  ) {
    final prefix = 'emoji[$contextId]';
    final isAnimated = (emoji as dynamic).isAnimated == true;
    final formatted = emoji.id == Snowflake.zero
        ? (emoji.name ?? '')
        : '<${isAnimated ? 'a' : ''}:${emoji.name}:${emoji.id}>';
    variables[prefix] = formatted;
    variables['$prefix.id'] = emoji.id.toString();
    variables['$prefix.name'] = emoji.name ?? '';
    variables['$prefix.isAnimated'] = isAnimated.toString();
  }
}
