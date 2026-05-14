part of '../event_contexts.dart';

EventExecutionContext buildTypingStartEventContext(TypingStartEvent event) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'typingStart',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: _asSnowflake(raw.userId),
    extra: <String, String>{
      'typing.timestamp': (raw.timestamp ?? '').toString(),
      'typing.member.id': _idString(raw.member?.id),
      'typing.member.name': (raw.member?.user?.username ?? '').toString(),
    },
  );
}
