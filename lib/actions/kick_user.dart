import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/actions/permission_checks.dart';
import 'package:bot_creator_shared/utils/global.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> kickUserAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'Missing guildId', 'userId': ''};
    }

    final userId = _toSnowflake(payload['userId']);
    if (userId == null) {
      return {'error': 'Missing or invalid userId', 'userId': ''};
    }

    final permError = await checkBotCanModerate(
      client,
      guildId: guildId,
      targetUserId: userId,
      requiredPermission: Permissions.kickMembers,
      actionLabel: 'kick',
    );
    if (permError != null) {
      return {'error': permError, 'userId': ''};
    }

    final reason = payload['reason']?.toString().trim();
    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found', 'userId': ''};
    await guild.members[userId].delete(
      auditLogReason:
          (reason != null && reason.isNotEmpty)
              ? reason
              : 'Kick via BotCreator action',
    );

    return {'userId': userId.toString()};
  } catch (error) {
    return {'error': 'Failed to kick user: $error', 'userId': ''};
  }
}
