import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'package:bot_creator_shared/utils/permission_flags.dart'
    show computeAllowBitmask, computeDenyBitmask;

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return Snowflake(parsed);
}

/// Resolve allow/deny bitmasks from a payload.
///
/// Supports both the new [permissionFlags] map format and the legacy
/// integer-string format. Returns (allow, deny) as [Permissions].
(Permissions, Permissions) _resolvePermissionBitmasks(
  Map<String, dynamic> payload,
  String Function(String) resolve,
) {
  // New format: 'permissions' Map<String, String>
  final permStates = payload['permissions'];
  if (permStates is Map && permStates.isNotEmpty) {
    final allowKeys = <String>{};
    final denyKeys = <String>{};
    permStates.forEach((key, value) {
      final state = resolve(value.toString());
      if (state == 'allow') {
        allowKeys.add(key.toString());
      } else if (state == 'deny') {
        denyKeys.add(key.toString());
      }
    });
    return (
      Permissions(computeAllowBitmask(allowKeys)),
      Permissions(computeDenyBitmask(denyKeys)),
    );
  }

  // Legacy format: 'allow' and 'deny' as integer strings
  final allowRaw =
      int.tryParse(resolve((payload['allow'] ?? '0').toString())) ?? 0;
  final denyRaw =
      int.tryParse(resolve((payload['deny'] ?? '0').toString())) ?? 0;
  return (Permissions(allowRaw), Permissions(denyRaw));
}

/// Edits a permission overwrite for a channel.
///
/// Payload fields:
/// - `channelId` — channel to edit (required)
/// - `targetId` — user or role ID (required, ignored when targetType is 'everyone')
/// - `targetType` — 'member', 'role', or 'everyone' (default 'member')
/// - `allow` — permissions bitmask to allow (as string integer, default '0')
/// - `deny` — permissions bitmask to deny (as string integer, default '0')
/// - `permissions` — (new format) Map of permission key → 'allow'/'deny'/'unset'
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

    final targetTypeRaw =
        resolve(
          (payload['targetType'] ?? 'member').toString(),
        ).trim().toLowerCase();
    final isEveryone = targetTypeRaw == 'everyone';
    final isMember =
        !isEveryone && (targetTypeRaw == 'member' || targetTypeRaw == 'user');

    // For @everyone, the target ID is the guild/server ID.
    // Otherwise use the value from the payload.
    final String resolvedTargetId;
    if (isEveryone) {
      resolvedTargetId = resolve('((guild.id))');
    } else {
      resolvedTargetId = resolve((payload['targetId'] ?? '').toString());
    }
    final targetId = _toSnowflake(resolvedTargetId);
    if (targetId == null) {
      return {'error': 'targetId is required for editChannelPermissions'};
    }

    final allowDeny = _resolvePermissionBitmasks(payload, resolve);
    final allow = allowDeny.$1;
    final deny = allowDeny.$2;

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
/// - `targetId` — user or role ID whose overwrite to delete (ignored when targetType is 'everyone')
/// - `targetType` — 'member', 'role', or 'everyone' (default 'member')
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

    final targetTypeRaw =
        resolve(
          (payload['targetType'] ?? 'member').toString(),
        ).trim().toLowerCase();
    final isEveryone = targetTypeRaw == 'everyone';

    final String resolvedTargetId;
    if (isEveryone) {
      resolvedTargetId = resolve('((guild.id))');
    } else {
      resolvedTargetId = resolve((payload['targetId'] ?? '').toString());
    }
    final targetId = _toSnowflake(resolvedTargetId);
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
