part of '../event_contexts.dart';

EventExecutionContext buildGuildAuditLogCreateEventContext(
  GuildAuditLogCreateEvent event,
) {
  final raw = event as dynamic;
  final entry = raw.entry;
  return _baseEventContext(
    eventName: 'guildAuditLogCreate',
    guildId: _asSnowflake(raw.guildId),
    channelId: null,
    userId: _asSnowflake(entry?.userId),
    extra: <String, String>{
      'auditLog.action': (entry?.actionType ?? '').toString(),
      'auditLog.executorId': _idString(entry?.userId),
      'auditLog.targetId': _idString(entry?.targetId),
    },
  );
}
