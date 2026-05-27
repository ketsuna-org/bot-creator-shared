part of '../event_contexts.dart';

EventExecutionContext buildGuildMemberAddEventContext(
  GuildMemberAddEvent event,
) {
  final member = event.member;
  final user = member.user;
  
  return _baseEventContext(
    eventName: 'guildMemberAdd',
    guildId: event.guildId,
    channelId: null,
    userId: member.id,
    member: member,
    extra: {
      ..._memberExtra(member),
      if (user != null) ..._userExtra(user, enrichAuthor: true),
    },
  );
}
