import 'package:bot_creator_shared/types/variable_suggestion.dart';

class VariableCatalog {
  /// Suggestions that are always available for BDFD expressions or BDFD/visual workflow templates.
  static List<VariableSuggestion> getAlwaysAvailableSuggestions({
    List<String> argumentNames = const [],
  }) {
    return [
      const VariableSuggestion(
        name: 'workflow.name',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      const VariableSuggestion(
        name: 'workflow.entryPoint',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      const VariableSuggestion(
        name: 'workflow.args',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      for (final argName in argumentNames) ...[
        VariableSuggestion(
          name: 'arg.$argName',
          kind: VariableSuggestionKind.unknown,
        ),
        VariableSuggestion(
          name: 'workflow.arg.$argName',
          kind: VariableSuggestionKind.unknown,
        ),
      ],
      // Bot prebuilt details
      const VariableSuggestion(name: 'bot.id', kind: VariableSuggestionKind.numeric),
      const VariableSuggestion(name: 'bot.username', kind: VariableSuggestionKind.nonNumeric),
      const VariableSuggestion(name: 'bot.guildCount', kind: VariableSuggestionKind.numeric),
      const VariableSuggestion(name: 'bot.guildNames', kind: VariableSuggestionKind.nonNumeric),
      const VariableSuggestion(name: 'bot.invite', kind: VariableSuggestionKind.nonNumeric),
      const VariableSuggestion(name: 'bot.ping', kind: VariableSuggestionKind.numeric),
      const VariableSuggestion(name: 'ping', kind: VariableSuggestionKind.numeric),
      const VariableSuggestion(name: 'bot.uptime', kind: VariableSuggestionKind.numeric),
      const VariableSuggestion(name: 'bot.shardId', kind: VariableSuggestionKind.numeric),
      const VariableSuggestion(name: 'bot.nodeVersion', kind: VariableSuggestionKind.nonNumeric),
      // Autocomplete details
      const VariableSuggestion(
        name: 'autocomplete.query',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      const VariableSuggestion(
        name: 'autocomplete.optionName',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      const VariableSuggestion(
        name: 'autocomplete.optionType',
        kind: VariableSuggestionKind.nonNumeric,
      ),
      // Builtin helpers
      const VariableSuggestion(name: 'length(source)', kind: VariableSuggestionKind.unknown),
      const VariableSuggestion(name: 'at(source, 0)', kind: VariableSuggestionKind.unknown),
      const VariableSuggestion(name: 'slice(source, 0, 10)', kind: VariableSuggestionKind.unknown),
      const VariableSuggestion(name: 'join(source, ", ")', kind: VariableSuggestionKind.unknown),
      const VariableSuggestion(name: 'formatEach(source, "{value}", ", ")', kind: VariableSuggestionKind.unknown),
      const VariableSuggestion(name: 'embedFields(source, "{name}", "{value}", true)', kind: VariableSuggestionKind.unknown),
      const VariableSuggestion(name: 'coin()', kind: VariableSuggestionKind.unknown),
      const VariableSuggestion(name: 'random()', kind: VariableSuggestionKind.unknown),
      const VariableSuggestion(name: 'randomchoice("a", "b", "c")', kind: VariableSuggestionKind.unknown),
      const VariableSuggestion(name: 'randomint(1, 100)', kind: VariableSuggestionKind.unknown),
    ];
  }

  /// Base hydrated context suggestions for Guild, Channel, and Member details.
  static List<VariableSuggestion> getBaseHydratedSuggestions() {
    return const [
      VariableSuggestion(name: 'event.name', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'timestamp', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'actualTime', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'guildId', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'channelId', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'userId', kind: VariableSuggestionKind.numeric),
      
      // Hydrated Guild
      VariableSuggestion(name: 'guild.id', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.name', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'guild.memberCount', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.count', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.ownerId', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.preferredLocale', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'guild.description', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'guild.vanityUrlCode', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'guild.verificationLevel', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'guild.mfaLevel', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'guild.nsfwLevel', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'guild.premiumTier', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.premiumSubscriptionCount', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.features', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'guild.features.count', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.systemChannelId', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.rulesChannelId', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.afkChannelId', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.afkTimeout', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.icon', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'guild.roleCount', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.roleNames', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'guild.stickerCount', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'guild.emojiCount', kind: VariableSuggestionKind.numeric),

      // Hydrated Channel
      VariableSuggestion(name: 'channel.id', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'channel.name', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'channel.type', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'channel.typeValue', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'channel.topic', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'channel.parentId', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'channel.categoryId', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'channel.position', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'channel.nsfw', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'channel.slowmode', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'channel.bitrate', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'channel.userLimit', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'channel.mention', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'channel.thread.archived', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'channel.thread.locked', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'channel.thread.ownerId', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'channel.thread.autoArchiveDuration', kind: VariableSuggestionKind.numeric),

      // Hydrated Member
      VariableSuggestion(name: 'member.id', kind: VariableSuggestionKind.numeric),
      VariableSuggestion(name: 'member.nick', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'member.displayName', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'member.avatar', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'member.joinedAt', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'member.roles', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'member.isBooster', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'member.premiumSince', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'member.communicationDisabledUntil', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'member.isAdmin', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'member.permissions', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'member.mention', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'user.mention', kind: VariableSuggestionKind.nonNumeric),
      VariableSuggestion(name: 'author.mention', kind: VariableSuggestionKind.nonNumeric),
    ];
  }

  /// Suggestions specific to a Discord Gateway Event name.
  static List<VariableSuggestion> getSuggestionsForEvent(String eventName) {
    final list = <VariableSuggestion>[];

    if (eventName.startsWith('message') &&
        !eventName.startsWith('messageReaction') &&
        !eventName.startsWith('messagePoll') &&
        !eventName.startsWith('messageBulk')) {
      list.addAll(const [
        VariableSuggestion(name: 'message.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'message.content', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'message.content[0]', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'message.content[1]', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'message.word.count', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'message.isBot', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'message.isSystem', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'message.mentions', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'message.mentions[0]', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'message.mention.count', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'author.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'author.name', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'author.isBot', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'author.avatar', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName.startsWith('guildMember')) {
      list.addAll(const [
        VariableSuggestion(name: 'member.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'member.name', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'member.joinedAt', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName == 'channelUpdate') {
      list.addAll(const [
        VariableSuggestion(name: 'channel.name', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'channel.type', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName == 'inviteCreate') {
      list.addAll(const [
        VariableSuggestion(name: 'invite.code', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'invite.channelId', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'invite.inviterId', kind: VariableSuggestionKind.numeric),
      ]);
    } else if (eventName == 'presenceUpdate') {
      list.addAll(const [
        VariableSuggestion(name: 'presence.status', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.activity.count', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'presence.activity[0].name', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.activity[0].type', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.activity[0].typeName', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.activity[0].details', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.activity[0].state', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.activity[0].url', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.activity[1].name', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.activity[1].type', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.activity[1].typeName', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.activity[1].details', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.activity[1].state', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.activity[1].url', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.client.desktop', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.client.mobile', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'presence.client.web', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'user.name', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName.startsWith('messageReaction')) {
      list.addAll(const [
        VariableSuggestion(name: 'message.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'reaction.emoji.name', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'reaction.emoji.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'reaction.emoji.animated', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName.startsWith('messagePollVote')) {
      list.addAll(const [
        VariableSuggestion(name: 'message.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'poll.answer.id', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'poll.question', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName == 'typingStart') {
      list.addAll(const [
        VariableSuggestion(name: 'typing.timestamp', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'typing.member.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'typing.member.name', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName == 'voiceStateUpdate') {
      list.addAll(const [
        VariableSuggestion(name: 'voice.channel.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'voice.user.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'voice.state.sessionId', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'voice.selfMute', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'voice.selfDeafen', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'voice.mute', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'voice.deafen', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName == 'voiceServerUpdate') {
      list.addAll(const [
        VariableSuggestion(name: 'voice.server.token', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'voice.server.endpoint', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName == 'voiceChannelEffectSend') {
      list.addAll(const [
        VariableSuggestion(name: 'voice.effect.emoji', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'voice.effect.soundId', kind: VariableSuggestionKind.numeric),
      ]);
    } else if (eventName == 'userUpdate') {
      list.addAll(const [
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'user.accentColor', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName.startsWith('guildRole')) {
      list.addAll(const [
        VariableSuggestion(name: 'role.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'role.name', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'role.color', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'role.permissions', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'role.position', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'role.mentionable', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'role.hoist', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName.startsWith('thread')) {
      list.addAll(const [
        VariableSuggestion(name: 'thread.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'thread.name', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'thread.parent.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'thread.owner.id', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'thread.archived', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'thread.locked', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'thread.autoArchiveDuration', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName == 'channelPinsUpdate') {
      list.addAll(const [
        VariableSuggestion(name: 'channel.lastPinTimestamp', kind: VariableSuggestionKind.nonNumeric),
      ]);
    } else if (eventName == 'inviteDelete') {
      list.addAll(const [
        VariableSuggestion(name: 'invite.code', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'invite.channelId', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'invite.inviterId', kind: VariableSuggestionKind.numeric),
      ]);
    } else if (eventName == 'guildAuditLogCreate') {
      list.addAll(const [
        VariableSuggestion(name: 'auditLog.action', kind: VariableSuggestionKind.nonNumeric),
        VariableSuggestion(name: 'auditLog.executorId', kind: VariableSuggestionKind.numeric),
        VariableSuggestion(name: 'auditLog.targetId', kind: VariableSuggestionKind.numeric),
      ]);
    }

    return list;
  }
}
