import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'permission_checks.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> removeRoleAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'Missing guildId', 'userId': '', 'roleId': ''};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.manageRoles],
      actionLabel: 'remove roles',
    );
    if (permError != null) {
      return {'error': permError, 'userId': '', 'roleId': ''};
    }

    final userId =
        _toSnowflake(payload['userId']) ?? _toSnowflake(payload['memberId']);
    if (userId == null) {
      return {
        'error': 'Missing or invalid userId/memberId',
        'userId': '',
        'roleId': '',
      };
    }

    final roleId = _toSnowflake(payload['roleId']);
    if (roleId == null) {
      return {'error': 'Missing or invalid roleId', 'userId': '', 'roleId': ''};
    }

    final reason = payload['reason']?.toString().trim();
    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) {
      return {'error': 'Guild not found', 'userId': '', 'roleId': ''};
    }
    await guild.members[userId].removeRole(
      roleId,
      auditLogReason:
          (reason != null && reason.isNotEmpty)
              ? reason
              : 'Remove role via BotCreator action',
    );

    return {
      'userId': userId.toString(),
      'roleId': roleId.toString(),
      'status': 'removed',
    };
  } catch (error) {
    return {
      'error': 'Failed to remove role: $error',
      'userId': '',
      'roleId': '',
    };
  }
}
