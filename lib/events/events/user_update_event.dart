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
      'user.avatar': user != null
          ? makeAvatarUrl(
            user.id.toString(),
            avatarId: (user as dynamic).avatar?.hash,
            isAnimated: (user as dynamic).avatar?.isAnimated ?? false,
            legacyFormat: 'webp',
            discriminator: (user as dynamic).discriminator,
          )
          : '',
      'user.banner': (user?.banner?.url?.toString() ?? '').toString(),
      'user.accentColor': (user?.accentColor?.toString() ?? '').toString(),
    },
  );
}
