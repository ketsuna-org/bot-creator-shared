import 'package:nyxx/nyxx.dart';
import 'handler_utils.dart';
import 'permission_checks.dart';

Future<Map<String, String>> setNicknameAction(
  NyxxGateway client, {
  required Snowflake guildId,
  required Map<String, dynamic> payload,
}) async {
  final userId = parseSnowflake(payload['userId']);
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

  final nickname = payload['nickname']?.toString() ?? '';
  final reason = payload['reason']?.toString();

  try {
    final member = await client.guilds[guildId].members.fetch(userId);
    await member.update(MemberUpdateBuilder(nick: nickname), auditLogReason: reason);
    return {'userId': userId.toString(), 'nickname': nickname};
  } catch (e) {
    return {'error': 'Failed to set nickname: $e'};
  }
}
