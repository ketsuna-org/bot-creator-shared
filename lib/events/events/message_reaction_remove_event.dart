part of '../event_contexts.dart';

EventExecutionContext buildMessageReactionRemoveEventContext(
  MessageReactionRemoveEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'messageReactionRemove',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: _asSnowflake(raw.userId),
    extra: _reactionEmojiExtra(raw, raw.emoji),
  );
}
