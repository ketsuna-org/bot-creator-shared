part of '../event_contexts.dart';

EventExecutionContext buildPresenceUpdateEventContext(
  PresenceUpdateEvent event,
) {
  final user = event.user;
  final fullUser = user is User ? user : null;
  final activities = event.activities ?? const <Activity>[];
  final extra = <String, String>{
    'user.id': user?.id.toString() ?? '',
    'user.name': fullUser?.username ?? '',
    'user.username': fullUser?.username ?? '',
    'user.tag': fullUser?.discriminator ?? '',
    'user.avatar': fullUser?.avatar.url.toString() ?? '',
    'presence.status': event.status?.value.toString() ?? '',
    'presence.activity.count': activities.length.toString(),
    'presence.client.desktop':
        event.clientStatus?.desktop?.value.toString() ?? '',
    'presence.client.mobile':
        event.clientStatus?.mobile?.value.toString() ?? '',
    'presence.client.web': event.clientStatus?.web?.value.toString() ?? '',
  };

  for (var i = 0; i < activities.length; i++) {
    final activity = activities[i];
    extra['presence.activity[$i].name'] = activity.name;
    extra['presence.activity[$i].type'] = activity.type.value.toString();
    extra['presence.activity[$i].typeName'] = _presenceActivityTypeName(
      activity.type.value,
    );
    extra['presence.activity[$i].details'] = activity.details ?? '';
    extra['presence.activity[$i].state'] = activity.state ?? '';
    extra['presence.activity[$i].url'] = activity.url?.toString() ?? '';
  }

  if (activities.isEmpty) {
    extra['presence.activity[0].name'] = '';
    extra['presence.activity[0].type'] = '';
    extra['presence.activity[0].typeName'] = '';
    extra['presence.activity[0].details'] = '';
    extra['presence.activity[0].state'] = '';
    extra['presence.activity[0].url'] = '';
  }

  return _baseEventContext(
    eventName: 'presenceUpdate',
    guildId: event.guildId,
    channelId: null,
    userId: user?.id,
    extra: extra,
  );
}

String _presenceActivityTypeName(int rawType) {
  switch (rawType) {
    case 0:
      return 'playing';
    case 1:
      return 'streaming';
    case 2:
      return 'listening';
    case 3:
      return 'watching';
    case 4:
      return 'custom';
    case 5:
      return 'competing';
    default:
      return rawType.toString();
  }
}
