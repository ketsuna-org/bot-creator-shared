import 'dart:convert';

import 'package:nyxx/nyxx.dart';
import '../utils/global.dart';

part 'events/channel_create_event.dart';
part 'events/channel_delete_event.dart';
part 'events/channel_pins_update_event.dart';
part 'events/channel_update_event.dart';
part 'events/guild_audit_log_create_event.dart';
part 'events/guild_create_event.dart';
part 'events/guild_delete_event.dart';
part 'events/guild_member_add_event.dart';
part 'events/guild_member_remove_event.dart';
part 'events/guild_member_update_event.dart';
part 'events/guild_role_create_event.dart';
part 'events/guild_role_delete_event.dart';
part 'events/guild_role_update_event.dart';
part 'events/guild_update_event.dart';
part 'events/invite_create_event.dart';
part 'events/invite_delete_event.dart';
part 'events/interaction_create_event.dart';
part 'events/message_create_event.dart';
part 'events/message_delete_event.dart';
part 'events/message_poll_vote_add_event.dart';
part 'events/message_poll_vote_remove_event.dart';
part 'events/message_reaction_add_event.dart';
part 'events/message_reaction_remove_all_event.dart';
part 'events/message_reaction_remove_emoji_event.dart';
part 'events/message_reaction_remove_event.dart';
part 'events/message_update_event.dart';
part 'events/presence_update_event.dart';
part 'events/thread_create_event.dart';
part 'events/thread_delete_event.dart';
part 'events/thread_member_update_event.dart';
part 'events/thread_members_update_event.dart';
part 'events/thread_update_event.dart';
part 'events/typing_start_event.dart';
part 'events/user_update_event.dart';
part 'events/voice_channel_effect_send_event.dart';
part 'events/voice_server_update_event.dart';
part 'events/voice_state_update_event.dart';

class EventExecutionContext {
  const EventExecutionContext({
    required this.eventName,
    required this.variables,
    required this.guildId,
    required this.channelId,
    required this.userId,
    this.messageId,
    this.interaction,
    this.member,
  });

  final String eventName;
  final Map<String, String> variables;
  final Snowflake? guildId;
  final Snowflake? channelId;
  final Snowflake? userId;
  final Snowflake? messageId;
  final Interaction? interaction;
  final PartialMember? member;
}

Map<String, String> _threadExtra(dynamic thread) {
  return <String, String>{
    'thread.id': _idString(thread?.id),
    'thread.name': (thread?.name ?? '').toString(),
    'thread.parent.id': _idString(thread?.parentId),
    'thread.owner.id': _idString(thread?.ownerId),
    'thread.archived': ((thread?.isArchived ?? false) == true).toString(),
    'thread.locked': ((thread?.isLocked ?? false) == true).toString(),
    'thread.autoArchiveDuration':
        (thread?.autoArchiveDuration ?? '').toString(),
  };
}

Future<Map<String, String>> _guildExtra(
  dynamic guild, {
  String prefix = 'guild',
  required Nyxx? client,
}) async {
  if (guild == null) return <String, String>{};
  
  final count = await getGuildMemberCount(
    guild,
    client: client,
    guildId: guild.id,
  );

  return <String, String>{
    '$prefix.id': _idString(guild.id),
    '$prefix.name': (guild.name ?? '').toString(),
    '$prefix.memberCount': count.toString(),
    '$prefix.systemChannelId': _idString(guild.systemChannelId),
    '$prefix.ownerId': _idString(guild.ownerId),
    '$prefix.preferredLocale': (guild.preferredLocale ?? '').toString(),
  };
}

Map<String, String> _roleExtRra(dynamic role) => <String, String>{
  'role.id': _idString(role?.id),
  'role.name': (role?.name ?? '').toString(),
  'role.color': _roleColorString(role),
  'role.permissions': (role?.permissions?.value ?? '').toString(),
  'role.position': (role?.position ?? '').toString(),
  'role.mentionable': ((role?.isMentionable ?? false) == true).toString(),
  'role.hoist': ((role?.isHoisted ?? false) == true).toString(),
};

String _roleColorString(dynamic role) {
  try {
    final dynamic colorValue = role?.colorValue;
    if (colorValue != null) {
      return colorValue.toString();
    }
  } catch (_) {}

  try {
    final dynamic color = role?.color;
    if (color == null) {
      return '';
    }
    if (color is num || color is String) {
      return color.toString();
    }
    final dynamic value = color.value;
    if (value != null) {
      return value.toString();
    }
    return color.toString();
  } catch (_) {
    return '';
  }
}

Map<String, String> _reactionEmojiExtra(dynamic raw, dynamic emoji) {
  bool animated = false;
  try {
    animated = (emoji?.isAnimated ?? false) == true;
  } catch (_) {}
  return <String, String>{
    'message.id': _idString(raw.messageId),
    'reaction.emoji.name': (emoji?.name ?? '').toString(),
    'reaction.emoji.id': _idString(emoji?.id),
    'reaction.emoji.animated': animated.toString(),
  };
}

Map<String, String> _memberBasicExtra(
  String memberId,
  String? username,
  String? discriminator,
) => <String, String>{
  'member.id': memberId,
  'member.name': username ?? '',
  'member.username': username ?? '',
  'member.tag': discriminator ?? '',
};

Map<String, String> _inviteExtra({
  required String code,
  required String channelId,
  required String inviterId,
}) => <String, String>{
  'invite.code': code,
  'invite.channelId': channelId,
  'invite.inviterId': inviterId,
};

Map<String, String> _pollVoteExtra({
  required Snowflake messageId,
  required int answerId,
}) => <String, String>{
  'message.id': messageId.toString(),
  'poll.answer.id': answerId.toString(),
};

Map<String, String> _messageContentExtra(Message message, {PartialMember? member}) {
  final author = message.author;
  final content = message.content;
  final words = content.trim().split(RegExp(r'\s+'));
  final mentionIds = message.mentions.map((u) => u.id.toString()).toList();
  final roleMentionIds =
      message.roleMentionIds.map((id) => id.toString()).toList();
  final isBot = author is User ? author.isBot : false;
  final authorId = author.id.toString();
  final authorName = author.username;
  final authorTag = author is User ? author.discriminator : '';
  final authorAvatar = author is User
      ? makeAvatarUrl(
        author.id.toString(),
        avatarId: author.avatar.hash,
        isAnimated: author.avatar.isAnimated,
        legacyFormat: 'webp',
        discriminator: author.discriminator,
      )
      : '';

  String authorBanner = '';
  String userCreatedAt = '';
  String userBannerColor = '';
  if (author is User) {
    authorBanner = author.banner?.url.toString() ?? '';
    userCreatedAt = author.id.timestamp.toIso8601String();
    final accentColor = author.accentColor;
    if (accentColor != null) {
      userBannerColor =
          '#${accentColor.value.toRadixString(16).padLeft(6, '0')}';
    }
  }

  final extra = <String, String>{
    'message.id': message.id.toString(),
    'message.content': content,
    'message.word.count': words.length.toString(),
    'message.isBot': isBot.toString(),
    'message.channelId': message.channelId.toString(),
    'message.isDM': (message.channel is DmChannel).toString(),
    'message.isSystem': (message.type != MessageType.normal).toString(),
    'message.type': message.type.value.toString(),
    'message.mentions': mentionIds.join(','),
    'message.mention.count': mentionIds.length.toString(),
    'message.timestamp': message.timestamp.millisecondsSinceEpoch.toString(),
    'message.isEdited': (message.editedTimestamp != null).toString(),
    'message.isPinned': message.isPinned.toString(),
    'message.attachments': message.attachments
        .map((a) => a.url.toString())
        .join(','),
    'message.attachments.count': message.attachments.length.toString(),
    'message.embeds.count': message.embeds.length.toString(),
    'message.roleMentions': roleMentionIds.join(','),
    'message.roleMentions.count': roleMentionIds.length.toString(),
    'message.mentionsEveryone': message.mentionsEveryone.toString(),
    'author.id': authorId,
    'author.name': authorName,
    'author.username': authorName,
    'author.globalName': author is User ? (author.globalName ?? authorName) : authorName,
    'author.tag': authorTag,
    'author.isBot': isBot.toString(),
    'author.avatar': authorAvatar,
    'author.banner': authorBanner,
    'author.displayName': author is User ? (author.globalName ?? authorName) : authorName,
    'userId': authorId,
    'userName': authorName,
    'userAvatar': authorAvatar,
    'user.id': authorId,
    'user.name': authorName,
    'user.username': authorName,
    'user.globalName': author is User ? (author.globalName ?? authorName) : authorName,
    'user.displayName': author is User ? (author.globalName ?? authorName) : authorName,
    'user.tag': authorTag,
    'user.avatar': authorAvatar,
    'user.banner': authorBanner,
    'user.createdAt': userCreatedAt,
    'user.bannerColor': userBannerColor,
    'interaction.user.id': authorId,
    'interaction.user.username': authorName,
    'interaction.user.tag': authorTag,
    'interaction.user.avatar': authorAvatar,
    if (member is Member) ...{
      'member.id': member.id.toString(),
      'member.nick': member.nick ?? '',
      'member.displayName': member.nick ?? (member.user?.globalName ?? member.user?.username ?? ''),
      'member.avatar': makeAvatarUrl(
        member.id.toString(),
        avatarId: member.avatar?.hash ?? member.user?.avatar.hash,
        isAnimated: member.avatar?.isAnimated ?? member.user?.avatar.isAnimated ?? false,
        legacyFormat: 'webp',
        discriminator: member.user?.discriminator,
      ),
      'member.joinedAt': member.joinedAt.toIso8601String(),
      'member.roles': member.roleIds.map((id) => id.toString()).join(','),
      'member.isBooster': (member.premiumSince != null).toString(),
      'member.isAdmin': member.permissions?.has(Permissions.administrator) == true
          ? 'true'
          : 'false',
    },
  };

  if (message.editedTimestamp != null) {
    extra['message.editedTimestamp'] =
        message.editedTimestamp!.millisecondsSinceEpoch.toString();
  }
  final referencedMessage = message.referencedMessage;
  if (referencedMessage != null) {
    extra['message.referencedMessage.id'] = referencedMessage.id.toString();
  }

  for (var idx = 0; idx < words.length && idx < 10; idx++) {
    extra['message.content[$idx]'] = words[idx];
  }
  for (var idx = 0; idx < mentionIds.length && idx < 10; idx++) {
    extra['message.mentions[$idx]'] = mentionIds[idx];
  }
  return extra;
}

Snowflake? _asSnowflake(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Snowflake) {
    return value;
  }
  if (value is int) {
    return Snowflake(value);
  }
  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

String _idString(dynamic value) {
  return _asSnowflake(value)?.toString() ?? (value?.toString() ?? '');
}

EventExecutionContext _baseEventContext({
  required String eventName,
  required Snowflake? guildId,
  required Snowflake? channelId,
  required Snowflake? userId,
  Snowflake? messageId,
  Interaction? interaction,
  PartialMember? member,
  Map<String, String> extra = const <String, String>{},
}) {
  final now = DateTime.now();
  return EventExecutionContext(
    eventName: eventName,
    guildId: guildId,
    channelId: channelId,
    userId: userId,
    messageId: messageId,
    interaction: interaction,
    member: member,
    variables: <String, String>{
      'event.name': eventName,
      'timestamp': now.millisecondsSinceEpoch.toString(),
      'actualTime': now.toIso8601String(),
      'guildId': guildId?.toString() ?? '',
      'channelId': channelId?.toString() ?? '',
      'userId': userId?.toString() ?? '',
      ...extra,
    },
  );
}

String _getChannelName(Channel channel) {
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
