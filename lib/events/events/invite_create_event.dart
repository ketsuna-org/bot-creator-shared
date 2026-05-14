part of '../event_contexts.dart';

EventExecutionContext buildInviteCreateEventContext(InviteCreateEvent event) {
  final invite = event.invite;
  return _baseEventContext(
    eventName: 'inviteCreate',
    guildId: invite.guild?.id,
    channelId: invite.channel.id,
    userId: invite.inviter?.id,
    extra: _inviteExtra(
      code: invite.code,
      channelId: invite.channel.id.toString(),
      inviterId: invite.inviter?.id.toString() ?? '',
    ),
  );
}
