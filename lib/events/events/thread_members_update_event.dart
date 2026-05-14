part of '../event_contexts.dart';

EventExecutionContext buildThreadMembersUpdateEventContext(
  ThreadMembersUpdateEvent event,
) {
  final added = event.addedMembers ?? const [];
  final removed = event.removedMemberIds ?? const [];
  return _baseEventContext(
    eventName: 'threadMembersUpdate',
    guildId: _asSnowflake(event.guildId),
    channelId: _asSnowflake(event.id),
    userId: null,
    extra: <String, String>{
      'thread.id': _idString(event.id),
      'thread.members.added.count': added.length.toString(),
      'thread.members.removed.count': removed.length.toString(),
    },
  );
}
