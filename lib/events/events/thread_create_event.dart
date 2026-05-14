part of '../event_contexts.dart';

EventExecutionContext buildThreadCreateEventContext(ThreadCreateEvent event) {
  final thread = event.thread;
  return _baseEventContext(
    eventName: 'threadCreate',
    guildId: _asSnowflake(thread.guildId),
    channelId: _asSnowflake(thread.id),
    userId: _asSnowflake(thread.ownerId),
    extra: _threadExtra(thread),
  );
}
