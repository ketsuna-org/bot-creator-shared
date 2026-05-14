part of '../event_contexts.dart';

EventExecutionContext buildMessageReactionRemoveEmojiEventContext(
  MessageReactionRemoveEmojiEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'messageReactionRemoveEmoji',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: null,
    extra: _reactionEmojiExtra(raw, raw.emoji),
  );
}
