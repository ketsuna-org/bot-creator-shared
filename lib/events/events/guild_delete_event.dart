part of '../event_contexts.dart';

EventExecutionContext buildGuildDeleteEventContext(GuildDeleteEvent event) {
  return _baseEventContext(
    eventName: 'guildDelete',
    guildId: event.guild.id,
    channelId: null,
    userId: null,
    extra: <String, String>{
      'guild.unavailable': event.isUnavailable.toString(),
    },
  );
}
