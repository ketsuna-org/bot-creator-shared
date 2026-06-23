part of '../event_contexts.dart';

EventExecutionContext buildMessageReactionAddEventContext(
  MessageReactionAddEvent event,
) {
  final raw = event as dynamic;
  final extra = <String, String>{
    ..._reactionEmojiExtra(raw, raw.emoji),
    if (raw.member is Member) ..._memberExtra(raw.member as Member),
  };
  return _baseEventContext(
    eventName: 'messageReactionAdd',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: _asSnowflake(raw.userId),
    extra: extra,
  );
}
