import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/actions/handler_utils.dart';
import 'permission_checks.dart';

Future<Map<String, String>> setNicknameAction(
  NyxxGateway client, {
  required Snowflake guildId,
  required Map<String, dynamic> payload,
  String Function(String)? resolve,
}) async {
  // Résoudre les variables dans le payload si une fonction resolve est fournie
  final resolvedPayload = resolve != null
      ? resolvePayloadValues(payload, resolve)
      : payload;

  final userId = parseSnowflake(resolvedPayload['userId']);
  if (userId == null) {
    return {'error': 'Invalid userId'};
  }

  final permError = await checkBotGuildPermission(
    client,
    guildId: guildId,
    requiredPermissions: [Permissions.manageNicknames],
    actionLabel: 'change nicknames',
  );
  if (permError != null) {
    return {'error': permError};
  }

  final nickname = resolvedPayload['nickname']?.toString() ?? '';
  final reason = resolvedPayload['reason']?.toString();

  try {
    final member = await client.guilds[guildId].members.fetch(userId);
    await member.update(MemberUpdateBuilder(nick: nickname), auditLogReason: reason);
    return {'userId': userId.toString(), 'nickname': nickname};
  } catch (e) {
    return {'error': 'Failed to set nickname: $e'};
  }
}