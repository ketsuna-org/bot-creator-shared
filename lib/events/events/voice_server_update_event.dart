part of '../event_contexts.dart';

EventExecutionContext buildVoiceServerUpdateEventContext(
  VoiceServerUpdateEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'voiceServerUpdate',
    guildId: _asSnowflake(raw.guildId),
    channelId: null,
    userId: null,
    extra: <String, String>{
      'voice.server.token': (raw.token ?? '').toString(),
      'voice.server.endpoint': (raw.endpoint ?? '').toString(),
    },
  );
}
