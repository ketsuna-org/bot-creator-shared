part of '../event_contexts.dart';

EventExecutionContext buildMessageReactionRemoveAllEventContext(
  MessageReactionRemoveAllEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'messageReactionRemoveAll',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: null,
    extra: <String, String>{'message.id': _idString(raw.messageId)},
  );
}
