part of '../event_contexts.dart';

EventExecutionContext buildChannelCreateEventContext(ChannelCreateEvent event) {
  final channel = event.channel;
  final guildId = channel is GuildChannel ? channel.guildId : null;
  return _baseEventContext(
    eventName: 'channelCreate',
    guildId: guildId,
    channelId: channel.id,
    userId: null,
    extra: <String, String>{
      'channel.id': channel.id.toString(),
      'channel.name': _getChannelName(channel),
      'channel.type': channel.type.toString(),
    },
  );
}
