part of '../event_contexts.dart';

EventExecutionContext buildThreadDeleteEventContext(ThreadDeleteEvent event) {
  final thread = event.deletedThread;
  return _baseEventContext(
    eventName: 'threadDelete',
    guildId: _asSnowflake(thread?.guildId),
    channelId: _asSnowflake(event.thread.id),
    userId: _asSnowflake(thread?.ownerId),
    extra: _threadExtra(thread),
  );
}
