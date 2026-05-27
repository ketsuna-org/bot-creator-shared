part of '../event_contexts.dart';

EventExecutionContext buildGuildMemberUpdateEventContext(
  GuildMemberUpdateEvent event,
) {
  final member = event.member;
  final user = member.user;
  final oldMember = event.oldMember;
  
  final extra = {
    ..._memberExtra(member),
    if (oldMember != null) ..._memberExtra(oldMember, prefix: 'member.old'),
    if (user != null) ..._userExtra(user, enrichAuthor: true),
  };

  return _baseEventContext(
    eventName: 'guildMemberUpdate',
    guildId: event.guildId,
    channelId: null, // Member updates are not channel-specific
    userId: member.id,
    member: member,
    extra: extra,
  );
}
