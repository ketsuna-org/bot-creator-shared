part of '../event_contexts.dart';

Future<EventExecutionContext> buildGuildCreateEventContext(
  GuildCreateEvent event,
) async {
  return _baseEventContext(
    eventName: 'guildCreate',
    guildId: event.guild.id,
    channelId: null,
    userId: null,
    extra: await _guildExtra(event.guild, client: event.guild.manager.client),
  );
}
