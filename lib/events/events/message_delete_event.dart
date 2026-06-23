part of '../event_contexts.dart';

EventExecutionContext buildMessageDeleteEventContext(MessageDeleteEvent event) {
  final deleted = event.deletedMessage;
  final author = deleted?.author;
  return _baseEventContext(
    eventName: 'messageDelete',
    guildId: event.guildId,
    channelId: event.channelId,
    userId: author?.id,
    extra: <String, String>{
      'message.id': event.id.toString(),
      'message.content': deleted?.content ?? '',
      if (author is User) ..._userExtra(author, enrichAuthor: true),
      if (author is! User) ...{
        'author.id': author?.id.toString() ?? '',
        'author.name': author?.username ?? '',
        'author.username': author?.username ?? '',
        'author.tag': '',
      },
    },
  );
}
