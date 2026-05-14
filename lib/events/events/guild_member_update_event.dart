part of '../event_contexts.dart';

EventExecutionContext buildGuildMemberUpdateEventContext(
  GuildMemberUpdateEvent event,
) {
  final member = event.member;
  final user = member.user;
  final oldMember = event.oldMember;
  
  final extra = {
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
      avatarId: member.avatar?.hash,
      isAnimated: member.avatar?.isAnimated ?? false,
      legacyFormat: 'webp',
      discriminator: user?.discriminator,
    ),
    'member.isBooster': (member.premiumSince != null).toString(),
  };

  if (oldMember != null) {
    extra['member.old.nick'] = oldMember.nick ?? '';
    extra['member.old.roles'] = oldMember.roleIds.map((id) => id.toString()).join(',');
    extra['member.old.avatar'] = makeAvatarUrl(
      oldMember.id.toString(),
      avatarId: oldMember.avatar?.hash,
      isAnimated: oldMember.avatar?.isAnimated ?? false,
      legacyFormat: 'webp',
      discriminator: user?.discriminator,
    );
    extra['member.old.isBooster'] = (oldMember.premiumSince != null).toString();
  }

  return _baseEventContext(
    eventName: 'guildMemberUpdate',
    guildId: event.guildId,
    channelId: null, // Member updates are not channel-specific
    userId: member.id,
    member: member,
    extra: extra,
  );
}
