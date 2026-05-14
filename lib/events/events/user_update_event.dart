part of '../event_contexts.dart';

EventExecutionContext buildUserUpdateEventContext(UserUpdateEvent event) {
  final raw = event as dynamic;
  final user = raw.user;
  return _baseEventContext(
    eventName: 'userUpdate',
    guildId: null,
    channelId: null,
    userId: _asSnowflake(user?.id),
    extra: <String, String>{
      'user.id': _idString(user?.id),
      'user.username': (user?.username ?? '').toString(),
      'user.avatar': (user?.avatar?.url?.toString() ?? '').toString(),
      'user.banner': (user?.banner?.url?.toString() ?? '').toString(),
      'user.accentColor': (user?.accentColor?.toString() ?? '').toString(),
    },
  );
}
