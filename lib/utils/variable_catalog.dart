import 'package:bot_creator_shared/types/variable_suggestion.dart';

/// Human-readable descriptions for the most commonly used variables.
/// Keys are variable names (lowercase), values are i18n-friendly descriptions
/// shown in the autocomplete UI as subtitles.
const Map<String, String> _descriptions = {
  // Context
  'workflow.name': 'Name of the current workflow',
  'workflow.entryPoint': 'Entry point that triggered this workflow',
  'workflow.args': 'Arguments passed to this workflow',
  'event.name': 'Name of the event that triggered the execution',
  'timestamp': 'Current Unix timestamp (seconds)',
  'actualtime': 'Current date and time as text',
  'guildid': 'ID of the current server',
  'channelid': 'ID of the current channel',
  'userid': 'ID of the user who triggered the command',
  'messageid': 'ID of the triggering message',
  // Bot
  'bot.id': 'Bot user ID',
  'bot.username': 'Bot username',
  'bot.guildcount': 'Number of servers the bot is in',
  'bot.guildnames': 'Names of all servers the bot is in',
  'bot.invite': 'Bot invite link',
  'bot.ping': 'Bot latency in milliseconds',
  'ping': 'Bot latency in milliseconds',
  'bot.uptime': 'Time since the bot started',
  'bot.shardid': 'Shard ID of this bot instance',
  'bot.nodeversion': 'Runtime version of the bot',
  // Guild
  'guild.id': 'Server ID',
  'guild.name': 'Server name',
  'guild.membercount': 'Total member count',
  'guild.count': 'Total member count',
  'guild.ownerid': 'Server owner ID',
  'guild.description': 'Server description',
  'guild.icon': 'Server icon URL',
  'guild.rolecount': 'Number of roles in the server',
  'guild.emojicount': 'Number of custom emojis',
  // Channel
  'channel.id': 'Channel ID',
  'channel.name': 'Channel name',
  'channel.topic': 'Channel topic/description',
  'channel.type': 'Channel type (text, voice, etc)',
  'channel.position': 'Channel position in the list',
  'channel.nsfw': 'Whether the channel is NSFW',
  'channel.slowmode': 'Slowmode delay in seconds',
  'channel.mention': 'Channel mention tag',
  // Member
  'member.id': 'Member user ID',
  'member.displayname': 'Member display name (nickname or username)',
  'member.nick': 'Member server nickname',
  'member.joinedat': 'When the member joined',
  'member.roles': 'List of role IDs the member has',
  'member.isadmin': 'Whether the member is administrator',
  'member.isbooster': 'Whether the member is a server booster',
  'member.permissions': 'Computed permissions of the member',
  'member.mention': 'Member mention tag',
  'member.avatar': 'Member avatar URL',
  'member.premiumSince': 'When the member started boosting',
  'member.roles[0]': 'First role ID',
  'member.roles[1]': 'Second role ID',
  // Message
  'message.id': 'Message ID',
  'message.content': 'Full message text content',
  'message.content[0]': 'First word of message content',
  'message.content[1]': 'Second word of message content',
  'message.content[2]': 'Third word of message content',
  'message.mentions': 'List of mentioned user IDs',
  'message.mentions[0]': 'First mentioned user ID',
  'message.mentions[1]': 'Second mentioned user ID',
  'message.mentions[2]': 'Third mentioned user ID',
  'message.mention.count': 'Number of users mentioned',
  'message.roleMentions': 'List of mentioned role IDs',
  'message.roleMentions.count': 'Number of mentioned roles',
  'message.roleMentions[0]': 'First mentioned role ID',
  // Author
  'author.id': 'Author user ID',
  'author.name': 'Author username',
  'author.isbot': 'Whether the author is a bot',
  'author.avatar': 'Author avatar URL',
  'author.mention': 'Author mention tag',
  // User
  'user.id': 'User ID',
  'user.name': 'Username',
  'user.username': 'Username',
  'user.avatar': 'User avatar URL',
  'user.mention': 'User mention tag',
  // Interaction
  'interaction.isslash': 'Whether triggered by a slash command',
  'interaction.command.name': 'Slash command name',
  'interaction.command.id': 'Slash command ID',
  'interaction.locale': 'Locale of the user who triggered the interaction (e.g. fr, ja)',
  'interaction.guild_locale': 'Locale of the guild where the interaction was triggered (e.g. en-US)',
  'target.locale': 'Alias for interaction.locale',
  // Autocomplete
  'autocomplete.query': 'Current autocomplete search text',
  'autocomplete.optionname': 'Name of the option being autocompleted',
  // Execution
  'execution.time': 'Time elapsed since execution started',
};

/// Returns a human-readable description for a variable name, if available.
String? variableDescription(String name) {
  return _descriptions[name.toLowerCase()];
}

/// Infers the [VariableCategory] from a variable name prefix.
///
/// This allows all suggestion assembly code to produce correct categories
/// without manually annotating every entry. Order matters: more specific
/// prefixes (e.g. `channel.thread.`) must come before general ones
/// (`channel.`).
VariableCategory inferCategory(String name) {
  final lower = name.toLowerCase();

  // Specific sub-prefixes first
  if (lower.startsWith('channel.thread.')) return VariableCategory.channel;
  if (lower.startsWith('interaction.')) return VariableCategory.interaction;
  if (lower.startsWith('autocomplete.')) return VariableCategory.interaction;
  if (lower.startsWith('opts.')) return VariableCategory.interaction;

  // Core entity prefixes
  if (lower.startsWith('guild.')) return VariableCategory.guild;
  if (lower.startsWith('channel.')) return VariableCategory.channel;
  if (lower.startsWith('member.')) return VariableCategory.member;
  if (lower.startsWith('author.')) return VariableCategory.author;
  if (lower.startsWith('user.')) return VariableCategory.user;
  if (lower.startsWith('bot.')) return VariableCategory.bot;
  if (lower.startsWith('message.')) return VariableCategory.message;
  if (lower.startsWith('temp.')) return VariableCategory.temp;

  // Context / execution
  if (lower.startsWith('workflow.')) return VariableCategory.context_;
  if (lower.startsWith('event.')) return VariableCategory.context_;
  if (lower.startsWith('execution.')) return VariableCategory.context_;

  // Entity lookup IDs (bare)
  if (lower == 'guildid' || lower == 'guildname') return VariableCategory.guild;
  if (lower == 'channelid' || lower == 'channelname') return VariableCategory.channel;
  if (lower == 'userid' || lower == 'username' || lower == 'usertag' ||
      lower == 'useravatar' || lower == 'userbanner') {
    return VariableCategory.user;
  }
  if (lower == 'messageid') return VariableCategory.message;
  if (lower == 'timestamp' || lower == 'actualtime') return VariableCategory.context_;

  // Functions (look like function calls)
  if (lower.contains('(')) return VariableCategory.function_;

  // Global/scoped variable references
  if (lower.startsWith('global.')) return VariableCategory.other;
  if (lower.contains('.bc_')) return VariableCategory.other;

  // Scoped aliases like `guild.bc_myVar` — already caught by `guild.` above,
  // but generic `scope.bc_key` falls here
  for (final scope in ['guild', 'user', 'channel', 'member', 'message']) {
    if (lower.startsWith('$scope.')) return VariableCategory.other;
  }

  // Event-specific prefixes
  if (lower.startsWith('voice.')) return VariableCategory.other;
  if (lower.startsWith('presence.')) return VariableCategory.other;
  if (lower.startsWith('reaction.')) return VariableCategory.other;
  if (lower.startsWith('poll.')) return VariableCategory.other;
  if (lower.startsWith('role.')) return VariableCategory.other;
  if (lower.startsWith('thread.')) return VariableCategory.other;
  if (lower.startsWith('invite.')) return VariableCategory.other;
  if (lower.startsWith('auditlog.')) return VariableCategory.other;
  if (lower.startsWith('typing.')) return VariableCategory.other;

  return VariableCategory.other;
}

class VariableCatalog {
  /// Suggestions that are always available for BDFD expressions or BDFD/visual workflow templates.
  static List<VariableSuggestion> getAlwaysAvailableSuggestions({
    List<String> argumentNames = const [],
  }) {
    return [
      const VariableSuggestion(
        name: 'workflow.name',
        kind: VariableSuggestionKind.nonNumeric,
        category: VariableCategory.context_,
      ),
      const VariableSuggestion(
        name: 'workflow.entryPoint',
        kind: VariableSuggestionKind.nonNumeric,
        category: VariableCategory.context_,
      ),
      const VariableSuggestion(
        name: 'workflow.args',
        kind: VariableSuggestionKind.nonNumeric,
        category: VariableCategory.context_,
      ),
      for (final argName in argumentNames) ...[
        VariableSuggestion(
          name: 'arg.$argName',
          kind: VariableSuggestionKind.unknown,
          category: VariableCategory.context_,
        ),
        VariableSuggestion(
          name: 'workflow.arg.$argName',
          kind: VariableSuggestionKind.unknown,
          category: VariableCategory.context_,
        ),
      ],
      // Bot prebuilt details
      const VariableSuggestion(name: 'bot.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.bot),
      const VariableSuggestion(name: 'bot.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.bot),
      const VariableSuggestion(name: 'bot.guildCount', kind: VariableSuggestionKind.numeric, category: VariableCategory.bot),
      const VariableSuggestion(name: 'bot.guildNames', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.bot),
      const VariableSuggestion(name: 'bot.invite', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.bot),
      const VariableSuggestion(name: 'bot.ping', kind: VariableSuggestionKind.numeric, category: VariableCategory.bot),
      const VariableSuggestion(name: 'ping', kind: VariableSuggestionKind.numeric, category: VariableCategory.bot),
      const VariableSuggestion(name: 'bot.uptime', kind: VariableSuggestionKind.numeric, category: VariableCategory.bot),
      const VariableSuggestion(name: 'bot.shardId', kind: VariableSuggestionKind.numeric, category: VariableCategory.bot),
      const VariableSuggestion(name: 'bot.nodeVersion', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.bot),
      // Autocomplete details
      const VariableSuggestion(name: 'autocomplete.query', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
      const VariableSuggestion(name: 'autocomplete.optionName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
      const VariableSuggestion(name: 'autocomplete.optionType', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
      // Interaction locale
      const VariableSuggestion(name: 'interaction.locale', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
      const VariableSuggestion(name: 'interaction.guild_locale', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
      const VariableSuggestion(name: 'target.locale', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
      // Builtin helpers
      const VariableSuggestion(name: 'length(source)', kind: VariableSuggestionKind.unknown, category: VariableCategory.function_),
      const VariableSuggestion(name: 'at(source, 0)', kind: VariableSuggestionKind.unknown, category: VariableCategory.function_),
      const VariableSuggestion(name: 'slice(source, 0, 10)', kind: VariableSuggestionKind.unknown, category: VariableCategory.function_),
      const VariableSuggestion(name: 'join(source, ", ")', kind: VariableSuggestionKind.unknown, category: VariableCategory.function_),
      const VariableSuggestion(name: 'formatEach(source, "{value}", ", ")', kind: VariableSuggestionKind.unknown, category: VariableCategory.function_),
      const VariableSuggestion(name: 'embedFields(source, "{name}", "{value}", true)', kind: VariableSuggestionKind.unknown, category: VariableCategory.function_),
      const VariableSuggestion(name: 'coin()', kind: VariableSuggestionKind.unknown, category: VariableCategory.function_),
      const VariableSuggestion(name: 'random()', kind: VariableSuggestionKind.unknown, category: VariableCategory.function_),
      const VariableSuggestion(name: 'randomchoice("a", "b", "c")', kind: VariableSuggestionKind.unknown, category: VariableCategory.function_),
      const VariableSuggestion(name: 'randomint(1, 100)', kind: VariableSuggestionKind.unknown, category: VariableCategory.function_),
    ];
  }

  /// Base hydrated context suggestions for Guild, Channel, and Member details.
  static List<VariableSuggestion> getBaseHydratedSuggestions() {
    return const [
      VariableSuggestion(name: 'event.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.context_),
      VariableSuggestion(name: 'timestamp', kind: VariableSuggestionKind.numeric, category: VariableCategory.context_),
      VariableSuggestion(name: 'actualTime', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.context_),
      VariableSuggestion(name: 'guildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'channelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'userId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
      VariableSuggestion(name: 'messageId', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),

      // Hydrated Guild
      VariableSuggestion(name: 'guild.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.memberCount', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.ownerId', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.preferredLocale', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.description', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.vanityUrlCode', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.verificationLevel', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.mfaLevel', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.nsfwLevel', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.premiumTier', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.premiumSubscriptionCount', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.features', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.features.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.systemChannelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.rulesChannelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.afkChannelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.afkTimeout', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.icon', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.roleCount', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.roleNames', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.stickerCount', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
      VariableSuggestion(name: 'guild.emojiCount', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),

      // Hydrated Channel
      VariableSuggestion(name: 'channel.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.type', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.typeValue', kind: VariableSuggestionKind.numeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.topic', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.parentId', kind: VariableSuggestionKind.numeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.categoryId', kind: VariableSuggestionKind.numeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.position', kind: VariableSuggestionKind.numeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.nsfw', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.slowmode', kind: VariableSuggestionKind.numeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.bitrate', kind: VariableSuggestionKind.numeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.userLimit', kind: VariableSuggestionKind.numeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.mention', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.thread.archived', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.thread.locked', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.thread.ownerId', kind: VariableSuggestionKind.numeric, category: VariableCategory.channel),
      VariableSuggestion(name: 'channel.thread.autoArchiveDuration', kind: VariableSuggestionKind.numeric, category: VariableCategory.channel),

      // Hydrated Member
      VariableSuggestion(name: 'member.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.nick', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.joinedAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.roles', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.roles.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.roles[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.roles[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.roles[2]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.isBooster', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.premiumSince', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.communicationDisabledUntil', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.isAdmin', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.permissions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
      VariableSuggestion(name: 'member.mention', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),

      // Hydrated User
      VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.accentColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.flags', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.publicFlags', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.avatarDecoration', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.avatarDecorationHash', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.avatarDecorationData.skuId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.avatarDecorationData.asset', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.primaryGuild.identityGuildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.primaryGuild.identityEnabled', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.primaryGuild.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.primaryGuild.badge', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.verified', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      VariableSuggestion(name: 'user.mention', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),

      // Hydrated Author
      VariableSuggestion(name: 'author.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.isBot', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.accentColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.flags', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.publicFlags', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.avatarDecoration', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.avatarDecorationHash', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.avatarDecorationData.skuId', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.avatarDecorationData.asset', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.primaryGuild.identityGuildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.primaryGuild.identityEnabled', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.primaryGuild.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.primaryGuild.badge', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.verified', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      VariableSuggestion(name: 'author.mention', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),

      // Hydrated Message
      VariableSuggestion(name: 'message.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.content', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.content[0]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.content[1]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.word.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.content[3]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.content[4]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.content[5]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.content[6]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.content[7]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.content[8]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.content[9]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.isBot', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.isDM', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.isSystem', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.type', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.channelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.timestamp', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.editedTimestamp', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.isEdited', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.isPinned', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.attachments', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.attachments.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.embeds.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mentions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mentions[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mention.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mentions[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mentions[2]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mentions[3]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mentions[4]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mentions[5]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mentions[6]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mentions[7]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mentions[8]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mentions[9]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.roleMentions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.roleMentions.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.roleMentions[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.roleMentions[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.roleMentions[2]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.mentionsEveryone', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.referencedMessage.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
      VariableSuggestion(name: 'message.url', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
    ];
  }

  /// Suggestions specific to a Discord Gateway Event name.
  /// Maps to the variables actually generated by each build*EventContext function.
  static List<VariableSuggestion> getSuggestionsForEvent(String eventName) {
    final list = <VariableSuggestion>[];

    // ═══════════════════════════════════════════════════════════════════
    // Message events (messageCreate, messageUpdate, messageDelete)
    // Runtime: _messageContentExtra → _messageExtra + _userExtra + _memberExtra
    // ═══════════════════════════════════════════════════════════════════
    if (eventName.startsWith('message') &&
        !eventName.startsWith('messageReaction') &&
        !eventName.startsWith('messagePoll') &&
        !eventName.startsWith('messageBulk')) {
      list.addAll([
        // ── Message fields (_messageExtra) ──
        VariableSuggestion(name: 'message.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[0]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[1]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[2]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.word.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[3]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[4]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[5]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[6]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[7]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[8]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[9]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.isBot', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.isDM', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.isSystem', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.type', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.channelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.timestamp', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.editedTimestamp', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.isEdited', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.isPinned', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.attachments', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.attachments.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.embeds.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mention.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[2]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[3]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[4]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[5]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[6]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[7]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[8]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[9]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.roleMentions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.roleMentions.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.roleMentions[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.roleMentions[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.roleMentions[2]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentionsEveryone', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.referencedMessage.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.url', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        // ── Author fields (_userExtra with enrichAuthor) ──
        VariableSuggestion(name: 'author.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.isBot', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.accentColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.flags', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.publicFlags', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatarDecoration', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatarDecorationHash', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatarDecorationData.skuId', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatarDecorationData.asset', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.primaryGuild.identityGuildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.primaryGuild.identityEnabled', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.primaryGuild.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.primaryGuild.badge', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.verified', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        // ── User fields (_userExtra) ──
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.accentColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.flags', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.publicFlags', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecoration', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationHash', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationData.skuId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationData.asset', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.identityGuildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.identityEnabled', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.badge', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.verified', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        // ── Interaction aliases ──
        VariableSuggestion(name: 'interaction.user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        // ── Legacy bare aliases ──
        VariableSuggestion(name: 'userId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'userName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'userAvatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        // ── Member fields (_memberExtra) ──
        VariableSuggestion(name: 'member.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.nick', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.joinedAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[2]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isBooster', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isAdmin', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.communicationDisabledUntil', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.permissions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.premiumSince', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.mention', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        // ── Update-specific ──
        if (eventName == 'messageUpdate')
          VariableSuggestion(name: 'message.oldContent', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Interaction create event
    // Runtime: buildInteractionRuntimeVariables
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName == 'interactionCreate') {
      list.addAll([
        // ── Core interaction fields ──
        VariableSuggestion(name: 'interaction.kind', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.customId', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.values', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.values.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.guildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.channelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.userId', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.messageId', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.token', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.applicationId', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.command.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.command.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.command.type', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.command.route', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        // ── Modal fields ──
        VariableSuggestion(name: 'modal.customId', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        // ── Select menu interaction fields (component interactions) ──
        VariableSuggestion(name: 'interaction.stringSelect.value', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.stringSelect.values', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.stringSelect.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.channelSelect.channelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.channelSelect.channelIds', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.channelSelect.channelCount', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.userSelect.userId', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.userSelect.userIds', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.userSelect.userCount', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.roleSelect.roleId', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.roleSelect.roleIds', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.roleSelect.roleCount', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.mentionableSelect.userId', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.mentionableSelect.userIds', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.mentionableSelect.userCount', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        // ── User fields (_userExtra) ──
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.accentColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.flags', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.publicFlags', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecoration', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationHash', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationData.skuId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationData.asset', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.identityGuildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.identityEnabled', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.badge', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.verified', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        // ── Author fields (enrichAuthor) ──
        VariableSuggestion(name: 'author.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.isBot', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.accentColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.flags', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.publicFlags', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatarDecoration', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatarDecorationHash', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatarDecorationData.skuId', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatarDecorationData.asset', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.primaryGuild.identityGuildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.primaryGuild.identityEnabled', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.primaryGuild.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.primaryGuild.badge', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.verified', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        // ── Member fields (_memberExtra) ──
        VariableSuggestion(name: 'member.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.nick', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.joinedAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[2]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isBooster', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isAdmin', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.communicationDisabledUntil', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.permissions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        // ── Message fields (_messageContentExtra) ──
        VariableSuggestion(name: 'message.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[0]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[1]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.word.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[3]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[4]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[5]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[6]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[7]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[8]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.content[9]', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.isBot', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.isDM', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.isSystem', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.type', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.channelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.timestamp', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.editedTimestamp', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.isEdited', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.isPinned', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.attachments', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.attachments.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.embeds.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mention.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[2]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[3]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[4]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[5]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[6]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[7]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[8]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentions[9]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.roleMentions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.roleMentions.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.roleMentions[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.roleMentions[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.roleMentions[2]', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.mentionsEveryone', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.referencedMessage.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'message.url', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.message),
        // ── Interaction user aliases ──
        VariableSuggestion(name: 'interaction.user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        VariableSuggestion(name: 'interaction.user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.interaction),
        // ── Legacy bare aliases ──
        VariableSuggestion(name: 'userId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'userName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'userAvatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Guild member events (guildMemberAdd, guildMemberRemove, guildMemberUpdate)
    // Runtime: _memberExtra(member) + _userExtra(user, enrichAuthor: true)
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName.startsWith('guildMember')) {
      list.addAll([
        // ── Member fields ──
        VariableSuggestion(name: 'member.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.nick', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.joinedAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[2]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isBooster', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isAdmin', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.communicationDisabledUntil', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        // ── User fields ──
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.accentColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.flags', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.publicFlags', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecoration', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationHash', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationData.skuId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationData.asset', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.identityGuildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.identityEnabled', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.badge', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.verified', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        // ── Author aliases (enrichAuthor: true) ──
        VariableSuggestion(name: 'author.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.isBot', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.accentColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.flags', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.publicFlags', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatarDecoration', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatarDecorationHash', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatarDecorationData.skuId', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatarDecorationData.asset', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.primaryGuild.identityGuildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.primaryGuild.identityEnabled', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.primaryGuild.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.primaryGuild.badge', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.verified', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        // ── Update-specific: old member ──
        if (eventName == 'guildMemberUpdate') ...[
          VariableSuggestion(name: 'member.old.nick', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
          VariableSuggestion(name: 'member.old.roles', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
          VariableSuggestion(name: 'member.old.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        ],
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Channel events (channelCreate, channelDelete, channelUpdate)
    // Runtime: _channelExtra(channel)
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName.startsWith('channel') &&
        !eventName.startsWith('channelPins')) {
      list.addAll([
        VariableSuggestion(name: 'channel.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.channel),
        VariableSuggestion(name: 'channel.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.channel),
        VariableSuggestion(name: 'channel.type', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.channel),
        if (eventName == 'channelUpdate')
          VariableSuggestion(name: 'channel.old.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.channel),
        if (eventName == 'channelUpdate')
          VariableSuggestion(name: 'channel.old.type', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.channel),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Guild events (guildCreate, guildDelete, guildUpdate)
    // Runtime: _guildExtra → guild.id, name, memberCount, systemChannelId, ownerId, preferredLocale
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName.startsWith('guild') &&
        !eventName.startsWith('guildMember') &&
        !eventName.startsWith('guildRole') &&
        !eventName.startsWith('guildAudit')) {
      list.addAll([
        VariableSuggestion(name: 'guild.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
        VariableSuggestion(name: 'guild.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
        VariableSuggestion(name: 'guild.memberCount', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
        VariableSuggestion(name: 'guild.systemChannelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
        VariableSuggestion(name: 'guild.ownerId', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
        VariableSuggestion(name: 'guild.preferredLocale', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
        if (eventName == 'guildDelete')
          VariableSuggestion(name: 'guild.unavailable', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
        if (eventName == 'guildUpdate') ...[
          VariableSuggestion(name: 'guild.oldGuild.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
          VariableSuggestion(name: 'guild.oldGuild.ownerId', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
          VariableSuggestion(name: 'guild.oldGuild.memberCount', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
          VariableSuggestion(name: 'guild.oldGuild.preferredLocale', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.guild),
          VariableSuggestion(name: 'guild.oldGuild.systemChannelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.guild),
        ],
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Invite events (inviteCreate, inviteDelete)
    // Runtime: _inviteExtra
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName.startsWith('invite')) {
      list.addAll([
        VariableSuggestion(name: 'invite.code', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'invite.channelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'invite.inviterId', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'invite.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'invite.maxAge', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'invite.maxUses', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'invite.isTemporary', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'invite.uses', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        // ── Inviter user fields (inviteCreate only) ──
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.mention', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Presence update event
    // Runtime: custom extra with presence.*, user.*
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName == 'presenceUpdate') {
      list.addAll([
        VariableSuggestion(name: 'presence.status', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'presence.activity.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'presence.activity[0].name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'presence.activity[0].type', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'presence.activity[0].typeName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'presence.activity[0].details', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'presence.activity[0].state', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'presence.activity[0].url', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'presence.client.desktop', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'presence.client.mobile', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'presence.client.web', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.accentColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.flags', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.publicFlags', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecoration', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationHash', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationData.skuId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationData.asset', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.identityGuildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.identityEnabled', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.badge', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.verified', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Message reaction events (messageReactionAdd, messageReactionRemove, etc.)
    // Runtime: _reactionEmojiExtra
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName.startsWith('messageReaction')) {
      list.addAll([
        VariableSuggestion(name: 'message.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'reaction.emoji.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'reaction.emoji.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'reaction.emoji.animated', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        // ── Member fields (messageReactionAdd from API; Remove/RemoveAll/RemoveEmoji resolved via cache/fetch hydration) ──
        VariableSuggestion(name: 'member.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.nick', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.joinedAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isBooster', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isAdmin', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.permissions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        // ── User fields (resolved via cache/fetch hydration) ──
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.mention', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Poll vote events (messagePollVoteAdd, messagePollVoteRemove)
    // Runtime: _pollVoteExtra
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName.startsWith('messagePollVote')) {
      list.addAll([
        VariableSuggestion(name: 'message.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.message),
        VariableSuggestion(name: 'poll.answer.id', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'poll.question', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'poll.vote.userId', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'poll.vote.channelId', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'poll.vote.guildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        // ── Member fields (resolved via cache/fetch hydration) ──
        VariableSuggestion(name: 'member.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.nick', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.joinedAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isBooster', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isAdmin', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        // ── User fields (resolved via cache/fetch hydration) ──
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.mention', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Typing start event
    // Runtime: custom extra
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName == 'typingStart') {
      list.addAll([
        VariableSuggestion(name: 'typing.timestamp', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'typing.member.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'typing.member.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        // ── Member fields (available when member data present) ──
        VariableSuggestion(name: 'member.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.nick', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.joinedAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isBooster', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isAdmin', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.permissions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        // ── User fields (available when member data present) ──
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.mention', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Voice state update event
    // Runtime: custom extra
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName == 'voiceStateUpdate') {
      list.addAll([
        VariableSuggestion(name: 'voice.channel.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'voice.user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'voice.state.sessionId', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'voice.selfMute', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'voice.selfDeafen', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'voice.mute', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'voice.deafen', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        // ── Member fields (available when member data present) ──
        VariableSuggestion(name: 'member.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.nick', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.joinedAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[0]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles[1]', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isBooster', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isAdmin', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.permissions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        // ── User fields (available when member data present) ──
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Voice server update event
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName == 'voiceServerUpdate') {
      list.addAll([
        VariableSuggestion(name: 'voice.server.token', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'voice.server.endpoint', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Voice channel effect send event
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName == 'voiceChannelEffectSend') {
      list.addAll([
        VariableSuggestion(name: 'voice.effect.emoji', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'voice.effect.soundId', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        // ── Member fields (resolved via cache/fetch hydration) ──
        VariableSuggestion(name: 'member.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.nick', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.joinedAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.roles.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isBooster', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        VariableSuggestion(name: 'member.isAdmin', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.member),
        // ── User fields (resolved via cache/fetch hydration) ──
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.mention', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // User update event
    // Runtime: custom extra with user.* fields
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName == 'userUpdate') {
      list.addAll([
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.flags', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.publicFlags', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecoration', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationHash', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationData.skuId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatarDecorationData.asset', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.identityGuildId', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.identityEnabled', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.primaryGuild.badge', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.verified', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.mention', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.accentColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Guild role events (guildRoleCreate, guildRoleDelete, guildRoleUpdate)
    // Runtime: _roleExtRra
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName.startsWith('guildRole')) {
      list.addAll([
        VariableSuggestion(name: 'role.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'role.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'role.color', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'role.permissions', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'role.position', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'role.mentionable', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'role.hoist', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Thread events (threadCreate, threadDelete, threadUpdate, threadMemberUpdate, threadMembersUpdate)
    // Runtime: _threadExtra
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName.startsWith('thread')) {
      list.addAll([
        VariableSuggestion(name: 'thread.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'thread.name', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'thread.parent.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'thread.owner.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'thread.archived', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'thread.locked', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'thread.autoArchiveDuration', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'thread.members.added.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'thread.members.removed.count', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Channel pins update event
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName == 'channelPinsUpdate') {
      list.addAll([
        VariableSuggestion(name: 'channel.lastPinTimestamp', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.channel),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Guild audit log create event
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName == 'guildAuditLogCreate') {
      list.addAll([
        VariableSuggestion(name: 'auditLog.action', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.other),
        VariableSuggestion(name: 'auditLog.executorId', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
        VariableSuggestion(name: 'auditLog.targetId', kind: VariableSuggestionKind.numeric, category: VariableCategory.other),
      ]);

    // ═══════════════════════════════════════════════════════════════════
    // Guild ban events (guildBanAdd, guildBanRemove)
    // Runtime: _userExtra(user, enrichAuthor: true)
    // ═══════════════════════════════════════════════════════════════════
    } else if (eventName == 'guildBanAdd' || eventName == 'guildBanRemove') {
      list.addAll([
        // ── User fields ──
        VariableSuggestion(name: 'user.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.banner', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.createdAt', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.bannerColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.accentColor', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        VariableSuggestion(name: 'user.mention', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.user),
        // ── Author fields (enrichAuthor) ──
        VariableSuggestion(name: 'author.id', kind: VariableSuggestionKind.numeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.username', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.globalName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.tag', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.avatar', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
        VariableSuggestion(name: 'author.displayName', kind: VariableSuggestionKind.nonNumeric, category: VariableCategory.author),
      ]);
    }

    return list;
  }
}
