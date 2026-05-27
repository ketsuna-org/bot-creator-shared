part of '../event_contexts.dart';

EventExecutionContext buildChannelUpdateEventContext(ChannelUpdateEvent event) {
  final channel = event.channel;
  final guildId = channel is GuildChannel ? channel.guildId : null;
  return _baseEventContext(
    eventName: 'channelUpdate',
    guildId: guildId,
    channelId: channel.id,
    userId: null,
    extra: {
      ..._channelExtra(channel),
      if (event.oldChannel != null) ..._channelExtra(event.oldChannel, prefix: 'channel.old'),
    },
  );
}
