part of '../event_contexts.dart';

EventExecutionContext buildGuildMemberAddEventContext(
  GuildMemberAddEvent event,
) {
  final member = event.member;
  final user = member.user;
  
  final userAvatarUrl = user != null
      ? makeAvatarUrl(
          user.id.toString(),
          avatarId: user.avatar.hash,
          isAnimated: user.avatar.isAnimated,
          legacyFormat: 'webp',
          discriminator: user.discriminator,
        )
      : '';

  return _baseEventContext(
    eventName: 'guildMemberAdd',
    guildId: event.guildId,
    channelId: null,
    userId: member.id,
    member: member,
    extra: {
      ..._memberBasicExtra(
        member.id.toString(),
        user?.username,
        user?.discriminator,
      ),
      'member.nick': member.nick ?? '',
      'member.joinedAt': member.joinedAt.toIso8601String(),
      'member.roles': member.roleIds.map((id) => id.toString()).join(','),
      'member.avatar': makeAvatarUrl(
        member.id.toString(),
        avatarId: member.avatar?.hash ?? user?.avatar.hash,
        isAnimated: member.avatar?.isAnimated ?? user?.avatar.isAnimated ?? false,
        legacyFormat: 'webp',
        discriminator: user?.discriminator,
      ),
      'member.isBooster': (member.premiumSince != null).toString(),
      if (user != null) ...{
        'user.id': user.id.toString(),
        'user.username': user.username,
        'user.globalName': user.globalName ?? user.username,
        'user.tag': user.discriminator,
        'user.avatar': userAvatarUrl,
        'user.createdAt': user.id.timestamp.toIso8601String(),
        'author.id': user.id.toString(),
        'author.username': user.username,
        'author.globalName': user.globalName ?? user.username,
        'author.tag': user.discriminator,
        'author.avatar': userAvatarUrl,
      },
    },
  );
}
