part of '../event_contexts.dart';

EventExecutionContext buildUserUpdateEventContext(UserUpdateEvent event) {
  final raw = event as dynamic;
  final user = raw.user;
  final extra = <String, String>{
    if (user is User) ..._userExtra(user),
    // user.accentColor is already set by _userExtra, but keep explicit
    // override to ensure it's always set even when user is not full User
    'user.accentColor': (user?.accentColor?.toString() ?? '').toString(),
  };
  return _baseEventContext(
    eventName: 'userUpdate',
    guildId: null,
    channelId: null,
    userId: _asSnowflake(user?.id),
    extra: extra,
  );
}
