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

Map<String, String> _userExtra(User? user, {bool enrichAuthor = false}) {
  if (user == null) return const <String, String>{};

  final userAvatarUrl = makeAvatarUrl(
    user.id.toString(),
    avatarId: user.avatar.hash,
    isAnimated: user.avatar.isAnimated,
    legacyFormat: 'webp',
    discriminator: user.discriminator,
  );
  String userBannerColor = '';
  final accentColor = user.accentColor;
  if (accentColor != null) {
    userBannerColor =
        '#${accentColor.value.toRadixString(16).padLeft(6, '0')}';
  }

  return <String, String>{
    'user.id': user.id.toString(),
    'user.username': user.username,
    'user.globalName': user.globalName ?? user.username,
    'user.displayName': user.globalName ?? user.username,
    'user.tag': user.discriminator,
    'user.avatar': userAvatarUrl,
    'user.banner': user.banner?.url.toString() ?? '',
    'user.createdAt': user.id.timestamp.toIso8601String(),
    'user.bannerColor': userBannerColor,
    if (enrichAuthor) ...{
      'author.id': user.id.toString(),
      'author.username': user.username,
      'author.globalName': user.globalName ?? user.username,
      'author.tag': user.discriminator,
      'author.avatar': userAvatarUrl,
      'author.banner': user.banner?.url.toString() ?? '',
      'author.displayName': user.globalName ?? user.username,
    },
  };
}

Map<String, String> _memberExtra(Member? member, {String prefix = 'member'}) {
  if (member == null) return const <String, String>{};

  final user = member.user;
  return <String, String>{
    if (prefix == 'member') ..._memberBasicExtra(
      member.id.toString(),
      user?.username,
      user?.discriminator,
    ),
    '$prefix.id': member.id.toString(),
    '$prefix.nick': member.nick ?? '',
    '$prefix.displayName': member.nick ?? (user?.globalName ?? user?.username ?? ''),
    '$prefix.avatar': makeAvatarUrl(
      member.id.toString(),
      avatarId: member.avatar?.hash ?? user?.avatar.hash,
      isAnimated: member.avatar?.isAnimated ?? user?.avatar.isAnimated ?? false,
      legacyFormat: 'webp',
      discriminator: user?.discriminator,
    ),
    '$prefix.joinedAt': member.joinedAt.toIso8601String(),
    '$prefix.roles': member.roleIds.map((id) => id.toString()).join(','),
    '$prefix.roles.count': member.roleIds.length.toString(),
    '$prefix.isBooster': (member.premiumSince != null).toString(),
    '$prefix.isAdmin': member.permissions?.has(Permissions.administrator) == true
        ? 'true'
        : 'false',
    if (member.communicationDisabledUntil != null)
      '$prefix.communicationDisabledUntil': member.communicationDisabledUntil!.toIso8601String(),
    if (user != null && prefix == 'member') ..._userExtra(user),
  };
}

Map<String, String> _channelExtra(Channel? channel, {String prefix = 'channel'}) {
  if (channel == null) return const <String, String>{};
  return <String, String>{
    '$prefix.id': channel.id.toString(),
    '$prefix.name': _getChannelName(channel),
    '$prefix.type': channel.type.toString(),
  };
}

Map<String, String> _messageExtra(Message? message, {String prefix = 'message'}) {
  if (message == null) return const <String, String>{};

  final content = message.content;
  final words = content.trim().split(RegExp(r'\s+'));
  final mentionIds = message.mentions.map((u) => u.id.toString()).toList();
  final roleMentionIds =
      message.roleMentionIds.map((id) => id.toString()).toList();
  final isBot = message.author is User ? (message.author as User).isBot : false;

  final map = <String, String>{
    '$prefix.id': message.id.toString(),
    '$prefix.content': content,
    '$prefix.word.count': words.length.toString(),
    '$prefix.isBot': isBot.toString(),
    '$prefix.channelId': message.channelId.toString(),
    '$prefix.isDM': (message.channel is DmChannel).toString(),
    '$prefix.isSystem': (message.type != MessageType.normal).toString(),
    '$prefix.type': message.type.value.toString(),
    '$prefix.mentions': mentionIds.join(','),
    '$prefix.mention.count': mentionIds.length.toString(),
    '$prefix.timestamp': message.timestamp.millisecondsSinceEpoch.toString(),
    '$prefix.isEdited': (message.editedTimestamp != null).toString(),
    '$prefix.isPinned': message.isPinned.toString(),
    '$prefix.attachments': message.attachments
        .map((a) => a.url.toString())
        .join(','),
    '$prefix.attachments.count': message.attachments.length.toString(),
    '$prefix.embeds.count': message.embeds.length.toString(),
    '$prefix.roleMentions': roleMentionIds.join(','),
    '$prefix.roleMentions.count': roleMentionIds.length.toString(),
    '$prefix.mentionsEveryone': message.mentionsEveryone.toString(),
  };

  if (message.editedTimestamp != null) {
    map['$prefix.editedTimestamp'] =
        message.editedTimestamp!.millisecondsSinceEpoch.toString();
  }
  final referencedMessage = message.referencedMessage;
  if (referencedMessage != null) {
    map['$prefix.referencedMessage.id'] = referencedMessage.id.toString();
  }

  for (var idx = 0; idx < words.length && idx < 10; idx++) {
    map['$prefix.content[$idx]'] = words[idx];
  }
  for (var idx = 0; idx < mentionIds.length && idx < 10; idx++) {
    map['$prefix.mentions[$idx]'] = mentionIds[idx];
  }
  return map;
}

Map<String, String> _inviteExtra(
  dynamic invite, {
  String? code,
  String? channelId,
  String? inviterId,
}) {
  if (invite == null) {
    return <String, String>{
      'invite.code': code ?? '',
      'invite.channelId': channelId ?? '',
      'invite.inviterId': inviterId ?? '',
    };
  }

  // Safe dynamic extraction
  String inviteCode = '';
  String chanId = '';
  String invId = '';
  try {
    inviteCode = invite.code?.toString() ?? '';
  } catch (_) {}
  try {
    chanId = invite.channel?.id?.toString() ?? '';
  } catch (_) {}
  try {
    invId = invite.inviter?.id?.toString() ?? '';
  } catch (_) {}

  final map = <String, String>{
    'invite.code': inviteCode.isNotEmpty ? inviteCode : (code ?? ''),
    'invite.channelId': chanId.isNotEmpty ? chanId : (channelId ?? ''),
    'invite.inviterId': invId.isNotEmpty ? invId : (inviterId ?? ''),
  };

  try {
    final dynamic dynInvite = invite;
    final createdAt = dynInvite.createdAt;
    if (createdAt is DateTime) {
      map['invite.createdAt'] = createdAt.toIso8601String();
    }
    final maxAge = dynInvite.maxAge;
    if (maxAge is Duration) {
      map['invite.maxAge'] = maxAge.inSeconds.toString();
    }
    final maxUses = dynInvite.maxUses;
    if (maxUses != null) {
      map['invite.maxUses'] = maxUses.toString();
    }
    final temporary = dynInvite.isTemporary ?? dynInvite.temporary;
    if (temporary != null) {
      map['invite.isTemporary'] = temporary.toString();
    }
    final uses = dynInvite.uses;
    if (uses != null) {
      map['invite.uses'] = uses.toString();
    }
  } catch (_) {}

  return map;
}

Map<String, String> _pollVoteExtra({
  required Snowflake messageId,
  required int answerId,
  Snowflake? userId,
  Snowflake? channelId,
  Snowflake? guildId,
}) => <String, String>{
  'message.id': messageId.toString(),
  'poll.answer.id': answerId.toString(),
  if (userId != null) 'poll.vote.userId': userId.toString(),
  if (channelId != null) 'poll.vote.channelId': channelId.toString(),
  if (guildId != null) 'poll.vote.guildId': guildId.toString(),
};

Map<String, String> _messageContentExtra(Message message, {PartialMember? member}) {
  final author = message.author;
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

  final extra = <String, String>{
    ..._messageExtra(message),
    if (author is User) ..._userExtra(author, enrichAuthor: true),
    if (author is! User) ...{
      'author.id': authorId,
      'author.name': authorName,
      'author.username': authorName,
      'author.displayName': authorName,
      'author.tag': authorTag,
      'author.isBot': 'false',
      'author.avatar': authorAvatar,
      'author.banner': '',
      'user.id': authorId,
      'user.name': authorName,
      'user.username': authorName,
      'user.globalName': authorName,
      'user.displayName': authorName,
      'user.tag': authorTag,
      'user.avatar': authorAvatar,
      'user.banner': '',
      'user.createdAt': '',
      'user.bannerColor': '',
    },
    'author.isBot': (author is User ? author.isBot : false).toString(),
    'userId': authorId,
    'userName': authorName,
    'userAvatar': authorAvatar,
    'interaction.user.id': authorId,
    'interaction.user.username': authorName,
    'interaction.user.tag': authorTag,
    'interaction.user.avatar': authorAvatar,
    if (member is Member) ..._memberExtra(member),
  };

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
