part of '../event_contexts.dart';

EventExecutionContext buildChannelDeleteEventContext(ChannelDeleteEvent event) {
  final channel = event.channel;
  final guildId = channel is GuildChannel ? channel.guildId : null;
  return _baseEventContext(
    eventName: 'channelDelete',
    guildId: guildId,
    channelId: channel.id,
    userId: null,
    extra: _channelExtra(channel),
  );
}
