part of '../event_contexts.dart';

Future<EventExecutionContext> buildGuildUpdateEventContext(
  GuildUpdateEvent event,
) async {
  final extra = await _guildExtra(event.guild, client: event.guild.manager.client);
  if (event.oldGuild != null) {
    extra.addAll(
      await _guildExtra(
        event.oldGuild,
        prefix: 'guild.oldGuild',
        client: event.guild.manager.client,
      ),
    );
  }

  return _baseEventContext(
    eventName: 'guildUpdate',
    guildId: event.guild.id,
    channelId: null,
    userId: null,
    extra: extra,
  );
}
