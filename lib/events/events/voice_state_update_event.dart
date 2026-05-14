part of '../event_contexts.dart';

EventExecutionContext buildVoiceStateUpdateEventContext(
  VoiceStateUpdateEvent event,
) {
  final state = event.state;
  return _baseEventContext(
    eventName: 'voiceStateUpdate',
    guildId: _asSnowflake(state.guildId),
    channelId: _asSnowflake(state.channelId),
    userId: _asSnowflake(state.userId),
    extra: <String, String>{
      'voice.channel.id': _idString(state.channelId),
      'voice.user.id': _idString(state.userId),
      'voice.state.sessionId': state.sessionId,
      'voice.selfMute': state.isSelfMuted.toString(),
      'voice.selfDeafen': state.isSelfDeafened.toString(),
      'voice.mute': state.isMuted.toString(),
      'voice.deafen': state.isDeafened.toString(),
    },
  );
}
