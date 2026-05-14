part of '../event_contexts.dart';

EventExecutionContext buildMessageDeleteEventContext(MessageDeleteEvent event) {
  final deleted = event.deletedMessage;
  return _baseEventContext(
    eventName: 'messageDelete',
    guildId: event.guildId,
    channelId: event.channelId,
    userId: deleted?.author.id,
    extra: <String, String>{
      'message.id': event.id.toString(),
      'message.content': deleted?.content ?? '',
      'author.id': deleted?.author.id.toString() ?? '',
      'author.name': deleted?.author.username ?? '',
      'author.username': deleted?.author.username ?? '',
      'author.tag':
          deleted?.author is User
              ? (deleted!.author as User).discriminator
              : '',
    },
  );
}
