part of '../event_contexts.dart';

EventExecutionContext buildGuildBanAddEventContext(
  GuildBanAddEvent event,
) {
  final user = event.user;
  return _baseEventContext(
    eventName: 'guildBanAdd',
    guildId: event.guildId,
    channelId: null,
    userId: user.id,
    extra: <String, String>{
      ..._userExtra(user, enrichAuthor: true),
    },
  );
}
