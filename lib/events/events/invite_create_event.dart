part of '../event_contexts.dart';

EventExecutionContext buildInviteCreateEventContext(InviteCreateEvent event) {
  final invite = event.invite;
  final extra = <String, String>{
    ..._inviteExtra(
      invite,
      code: invite.code,
      channelId: invite.channel.id.toString(),
      inviterId: invite.inviter?.id.toString() ?? '',
    ),
    if (invite.inviter is User) ..._userExtra(invite.inviter as User),
  };
  return _baseEventContext(
    eventName: 'inviteCreate',
    guildId: invite.guild?.id,
    channelId: invite.channel.id,
    userId: invite.inviter?.id,
    extra: extra,
  );
}
