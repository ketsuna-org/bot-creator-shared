part of '../event_contexts.dart';

EventExecutionContext buildInviteDeleteEventContext(InviteDeleteEvent event) {
  return _baseEventContext(
    eventName: 'inviteDelete',
    guildId: _asSnowflake(event.guildId),
    channelId: _asSnowflake(event.channelId),
    userId: null,
    extra: _inviteExtra(
      code: event.code,
      channelId: event.channelId.toString(),
      inviterId: '',
    ),
  );
}
