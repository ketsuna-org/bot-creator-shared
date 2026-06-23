part of '../event_contexts.dart';

EventExecutionContext buildMessagePollVoteAddEventContext(
  MessagePollVoteAddEvent event,
) {
  final raw = event as dynamic;
  final extra = <String, String>{
    ..._pollVoteExtra(
      messageId: event.messageId,
      answerId: event.answerId,
      userId: event.userId,
      channelId: event.channelId,
      guildId: event.guildId,
    ),
    if (raw.member is Member) ..._memberExtra(raw.member as Member),
  };
  return _baseEventContext(
    eventName: 'messagePollVoteAdd',
    guildId: _asSnowflake(event.guildId),
    channelId: _asSnowflake(event.channelId),
    userId: _asSnowflake(event.userId),
    extra: extra,
  );
}
