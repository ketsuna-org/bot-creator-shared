part of '../event_contexts.dart';

EventExecutionContext buildVoiceChannelEffectSendEventContext(
  VoiceChannelEffectSendEvent event,
) {
  final raw = event as dynamic;
  return _baseEventContext(
    eventName: 'voiceChannelEffectSend',
    guildId: _asSnowflake(raw.guildId),
    channelId: _asSnowflake(raw.channelId),
    userId: _asSnowflake(raw.userId),
    extra: <String, String>{
      'voice.effect.emoji': (raw.emoji?.name ?? '').toString(),
      'voice.effect.soundId': _idString(raw.soundId),
    },
  );
}
