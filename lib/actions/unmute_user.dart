import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'package:bot_creator_shared/actions/handler_utils.dart';
import 'permission_checks.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> unmuteUserAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  String Function(String)? resolve,
}) async {
  // Résoudre les variables dans le payload si une fonction resolve est fournie
  final resolvedPayload = resolve != null
      ? resolvePayloadValues(payload, resolve)
      : payload;

  try {
    if (guildId == null) {
      return {'error': 'Missing guildId', 'userId': ''};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.moderateMembers],
      actionLabel: 'unmute this user',
    );
    if (permError != null) {
      return {'error': permError, 'userId': ''};
    }

    final userId =
        _toSnowflake(resolvedPayload['userId']) ?? _toSnowflake(resolvedPayload['memberId']);
    if (userId == null) {
      return {'error': 'Missing or invalid userId/memberId', 'userId': ''};
    }

    final reason = resolvedPayload['reason']?.toString().trim();
    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found', 'userId': ''};
    final member = await guild.members[userId].update(
      MemberUpdateBuilder(communicationDisabledUntil: null),
      auditLogReason:
          (reason != null && reason.isNotEmpty)
              ? reason
              : 'Remove timeout via BotCreator action',
    );

    return {'userId': member.id.toString(), 'status': 'unmuted'};
  } catch (error) {
    return {'error': 'Failed to unmute user: $error', 'userId': ''};
  }
}
