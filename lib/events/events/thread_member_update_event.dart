part of '../event_contexts.dart';

EventExecutionContext buildThreadMemberUpdateEventContext(
  ThreadMemberUpdateEvent event,
) {
  final member = event.member;
  return _baseEventContext(
    eventName: 'threadMemberUpdate',
    guildId: _asSnowflake(event.guildId),
    channelId: _asSnowflake(member.threadId),
    userId: _asSnowflake(member.userId),
    extra: <String, String>{
      'thread.id': _idString(member.threadId),
      'member.id': _idString(member.userId),
    },
  );
}
