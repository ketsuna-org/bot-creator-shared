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
    extra: {
      ..._memberBasicExtra(
        member.id.toString(),
        user?.username,
        user?.discriminator,
      ),
      'member.joinedAt': member.joinedAt.toIso8601String(),
    },
  );
}
