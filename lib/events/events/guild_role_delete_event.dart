part of '../event_contexts.dart';

EventExecutionContext buildGuildRoleDeleteEventContext(
  GuildRoleDeleteEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'guildRoleDelete',
    guildId: _asSnowflake(raw.guildId),
    channelId: null,
    userId: null,
    extra: <String, String>{'role.id': _idString(raw.roleId)},
  );
}
