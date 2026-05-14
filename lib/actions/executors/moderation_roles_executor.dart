import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';
import '../add_role.dart';
import '../ban_user.dart';
import '../kick_user.dart';
import '../mute_user.dart';
import '../remove_role.dart';
import '../set_nickname.dart';
import '../unban_user.dart';
import '../unmute_user.dart';

Future<bool> executeModerationRolesAction({
  required BotCreatorActionType type,
  required NyxxGateway client,
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required String Function(String input) resolveValue,
}) async {
  switch (type) {
    case BotCreatorActionType.banUser:
    case BotCreatorActionType.unbanUser:
    case BotCreatorActionType.kickUser:
    case BotCreatorActionType.muteUser:
    case BotCreatorActionType.unmuteUser:
    case BotCreatorActionType.addRole:
    case BotCreatorActionType.removeRole:
      if (guildId == null) {
        throw Exception('User action requires a guild context');
      }

      final resolvedPayload = Map<String, dynamic>.from(payload);
      if (payload.containsKey('userId')) {
        resolvedPayload['userId'] = resolveValue(payload['userId'].toString());
      }
      if (payload.containsKey('memberId')) {
        resolvedPayload['memberId'] = resolveValue(
          payload['memberId'].toString(),
        );
      }
      if (payload.containsKey('roleId')) {
        resolvedPayload['roleId'] = resolveValue(payload['roleId'].toString());
      }
      if (payload.containsKey('reason')) {
        resolvedPayload['reason'] = resolveValue(payload['reason'].toString());
      }
      if (payload.containsKey('deleteMessageDays')) {
        resolvedPayload['deleteMessageDays'] = resolveValue(
          payload['deleteMessageDays'].toString(),
        );
      }
      if (payload.containsKey('duration')) {
        resolvedPayload['duration'] = resolveValue(
          payload['duration'].toString(),
        );
      }
      if (payload.containsKey('durationSeconds')) {
        resolvedPayload['durationSeconds'] = resolveValue(
          payload['durationSeconds'].toString(),
        );
      }
      if (payload.containsKey('durationMinutes')) {
        resolvedPayload['durationMinutes'] = resolveValue(
          payload['durationMinutes'].toString(),
        );
      }
      if (payload.containsKey('durationHours')) {
        resolvedPayload['durationHours'] = resolveValue(
          payload['durationHours'].toString(),
        );
      }
      if (payload.containsKey('until')) {
        resolvedPayload['until'] = resolveValue(payload['until'].toString());
      }

      final result = await switch (type) {
        BotCreatorActionType.banUser => banUserAction(
          client,
          guildId: guildId,
          payload: resolvedPayload,
        ),
        BotCreatorActionType.unbanUser => unbanUserAction(
          client,
          guildId: guildId,
          payload: resolvedPayload,
        ),
        BotCreatorActionType.kickUser => kickUserAction(
          client,
          guildId: guildId,
          payload: resolvedPayload,
        ),
        BotCreatorActionType.muteUser => muteUserAction(
          client,
          guildId: guildId,
          payload: resolvedPayload,
        ),
        BotCreatorActionType.unmuteUser => unmuteUserAction(
          client,
          guildId: guildId,
          payload: resolvedPayload,
        ),
        BotCreatorActionType.addRole => addRoleAction(
          client,
          guildId: guildId,
          payload: resolvedPayload,
        ),
        BotCreatorActionType.removeRole => removeRoleAction(
          client,
          guildId: guildId,
          payload: resolvedPayload,
        ),
        BotCreatorActionType.setNickname => setNicknameAction(
          client,
          guildId: guildId,
          payload: resolvedPayload,
        ),
        _ => throw Exception('Unexpected action type'),
      };

      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['userId'] ?? '';
      return true;

    default:
      return false;
  }
}
