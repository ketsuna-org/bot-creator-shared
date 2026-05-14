part of '../event_contexts.dart';

EventExecutionContext buildGuildMemberRemoveEventContext(
  GuildMemberRemoveEvent event,
) {
  final user = event.user;
  return _baseEventContext(
    eventName: 'guildMemberRemove',
    guildId: event.guildId,
    channelId: null,
    userId: user.id,
    extra: _memberBasicExtra(
      user.id.toString(),
      user.username,
      user.discriminator,
    ),
  );
}
