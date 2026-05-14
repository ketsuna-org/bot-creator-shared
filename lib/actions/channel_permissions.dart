import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return Snowflake(parsed);
}

/// Edits a permission overwrite for a channel.
///
/// Payload fields:
/// - `channelId` — channel to edit (required)
/// - `targetId` — user or role ID (required)
/// - `targetType` — 'member' or 'role' (required)
/// - `allow` — permissions bitmask to allow (as string integer, default '0')
/// - `deny` — permissions bitmask to deny (as string integer, default '0')
/// - `reason` — audit log reason
///
/// Returns `{'channelId', 'targetId', 'status': 'updated'}` or `{'error': '...'}`.
Future<Map<String, String>> editChannelPermissionsAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  Snowflake? fallbackChannelId,
  required String Function(String) resolve,
}) async {
  try {
    final channelId =
        _toSnowflake(resolve((payload['channelId'] ?? '').toString())) ??
        fallbackChannelId;
    if (channelId == null) {
      return {'error': 'channelId is required for editChannelPermissions'};
    }

    final targetId = _toSnowflake(
      resolve((payload['targetId'] ?? '').toString()),
    );
    if (targetId == null) {
      return {'error': 'targetId is required for editChannelPermissions'};
    }

    final targetTypeRaw =
        resolve(
          (payload['targetType'] ?? 'member').toString(),
        ).trim().toLowerCase();
    final isMember = targetTypeRaw == 'member' || targetTypeRaw == 'user';

    final allowRaw =
        int.tryParse(resolve((payload['allow'] ?? '0').toString())) ?? 0;
    final denyRaw =
        int.tryParse(resolve((payload['deny'] ?? '0').toString())) ?? 0;

    final allow = Permissions(allowRaw);
    final deny = Permissions(denyRaw);

    final channel = await fetchChannelCached(client, channelId);
    if (channel is! GuildChannel) {
      return {'error': 'Channel is not a guild channel'};
    }

    await channel.updatePermissionOverwrite(
      PermissionOverwriteBuilder(
        id: targetId,
        type:
            isMember
                ? PermissionOverwriteType.member
                : PermissionOverwriteType.role,
        allow: allow,
        deny: deny,
      ),
    );

    return {
      'channelId': channelId.toString(),
      'targetId': targetId.toString(),
      'status': 'updated',
    };
  } catch (e) {
    return {'error': 'Failed to edit channel permissions: $e'};
  }
}

/// Deletes a permission overwrite from a channel.
///
/// Payload fields:
/// - `channelId` — channel to edit (required)
/// - `targetId` — user or role ID whose overwrite to delete (required)
/// - `reason` — audit log reason
///
/// Returns `{'channelId', 'targetId', 'status': 'deleted'}` or `{'error': '...'}`.
Future<Map<String, String>> deleteChannelPermissionAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  Snowflake? fallbackChannelId,
  required String Function(String) resolve,
}) async {
  try {
    final channelId =
        _toSnowflake(resolve((payload['channelId'] ?? '').toString())) ??
        fallbackChannelId;
    if (channelId == null) {
      return {'error': 'channelId is required for deleteChannelPermission'};
    }

    final targetId = _toSnowflake(
      resolve((payload['targetId'] ?? '').toString()),
    );
    if (targetId == null) {
      return {'error': 'targetId is required for deleteChannelPermission'};
    }

    final channel = await fetchChannelCached(client, channelId);
    if (channel is! GuildChannel) {
      return {'error': 'Channel is not a guild channel'};
    }

    await channel.deletePermissionOverwrite(targetId);

    return {
      'channelId': channelId.toString(),
      'targetId': targetId.toString(),
      'status': 'deleted',
    };
  } catch (e) {
    return {'error': 'Failed to delete channel permission: $e'};
  }
}
