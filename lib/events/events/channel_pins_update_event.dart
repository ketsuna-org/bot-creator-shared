part of '../event_contexts.dart';

EventExecutionContext buildChannelPinsUpdateEventContext(
  ChannelPinsUpdateEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'channelPinsUpdate',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: null,
    extra: <String, String>{
      'channel.lastPinTimestamp': (raw.lastPinTimestamp ?? '').toString(),
    },
  );
}
