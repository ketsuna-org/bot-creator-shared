part of '../event_contexts.dart';

EventExecutionContext buildMessageCreateEventContext(MessageCreateEvent event) {
  final message = event.message;
  final guildId = event.guildId;
  final extra = _messageContentExtra(message, member: event.member);
  if (guildId != null) {
    extra['message.url'] = 
        'https://discord.com/channels/$guildId/${message.channelId}/${message.id}';
  } else {
    extra['message.url'] =
        'https://discord.com/channels/@me/${message.channelId}/${message.id}';
  }
  return _baseEventContext(
    eventName: 'messageCreate',
    guildId: guildId,
    channelId: message.channelId,
    userId: message.author.id,
    messageId: message.id,
    member: event.member,
    extra: extra,
  );
}
