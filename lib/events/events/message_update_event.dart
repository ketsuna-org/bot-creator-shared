part of '../event_contexts.dart';

EventExecutionContext buildMessageUpdateEventContext(MessageUpdateEvent event) {
  final message = event.message;
  return _baseEventContext(
    eventName: 'messageUpdate',
    guildId: event.guildId,
    channelId: message.channelId,
    userId: message.author.id,
    extra: {
      ..._messageContentExtra(message),
      'message.oldContent': event.oldMessage?.content ?? '',
    },
  );
}
