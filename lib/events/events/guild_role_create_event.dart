part of '../event_contexts.dart';

EventExecutionContext buildGuildRoleCreateEventContext(
  GuildRoleCreateEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'guildRoleCreate',
    guildId: _asSnowflake(raw.guildId),
    channelId: null,
    userId: null,
    extra: _roleExtRra(raw.role),
  );
}
