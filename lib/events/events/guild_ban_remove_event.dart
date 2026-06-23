part of '../event_contexts.dart';

EventExecutionContext buildGuildBanRemoveEventContext(
  GuildBanRemoveEvent event,
) {
  final user = event.user;
  return _baseEventContext(
    eventName: 'guildBanRemove',
    guildId: event.guildId,
    channelId: null,
    userId: user.id,
    extra: <String, String>{
      ..._userExtra(user, enrichAuthor: true),
    },
  );
}
