part of '../event_contexts.dart';

EventExecutionContext buildGuildRoleUpdateEventContext(
  GuildRoleUpdateEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'guildRoleUpdate',
    guildId: _asSnowflake(raw.guildId),
    channelId: null,
    userId: null,
    extra: _roleExtRra(raw.role),
  );
}
