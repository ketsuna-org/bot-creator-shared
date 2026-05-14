part of '../event_contexts.dart';

EventExecutionContext buildMessagePollVoteAddEventContext(
  MessagePollVoteAddEvent event,
) {
  return _baseEventContext(
    eventName: 'messagePollVoteAdd',
    guildId: _asSnowflake(event.guildId),
    channelId: _asSnowflake(event.channelId),
    userId: _asSnowflake(event.userId),
    extra: _pollVoteExtra(messageId: event.messageId, answerId: event.answerId),
  );
}
