import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';
import '../add_reaction.dart';
import '../clear_all_reactions.dart';
import '../permission_checks.dart';
import '../remove_reaction.dart';

Future<bool> executeReactionsAction({
  required BotCreatorActionType type,
  required NyxxGateway client,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Snowflake? fallbackChannelId,
  required String Function(String input) resolveValue,
  Snowflake? guildId,
  BotPermissionCache? permissionCache,
}) async {
  final resolvedPayload = Map<String, dynamic>.from(payload);
  if (payload.containsKey('messageId')) {
    resolvedPayload['messageId'] = resolveValue(payload['messageId'].toString());
  }
  if (payload.containsKey('userId')) {
    resolvedPayload['userId'] = resolveValue(payload['userId'].toString());
  }
  if (payload.containsKey('emoji')) {
    resolvedPayload['emoji'] = resolveValue(payload['emoji'].toString());
  }

  switch (type) {
    case BotCreatorActionType.addReaction:
      if (guildId != null) {
        final permError = await checkBotGuildPermission(
          client,
          guildId: guildId,
          requiredPermissions: [
            Permissions.addReactions,
            Permissions.readMessageHistory,
          ],
          actionLabel: 'add reactions',
          cache: permissionCache,
        );
        if (permError != null) {
          throw Exception(permError);
        }
      }
      final result = await addReactionAction(
        client,
        payload: resolvedPayload,
        fallbackChannelId: fallbackChannelId,
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['status'] ?? 'OK';
      return true;

    case BotCreatorActionType.removeReaction:
      final result = await removeReactionAction(
        client,
        payload: resolvedPayload,
        fallbackChannelId: fallbackChannelId,
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['status'] ?? 'OK';
      return true;

    case BotCreatorActionType.clearAllReactions:
      if (guildId != null) {
        final permError = await checkBotGuildPermission(
          client,
          guildId: guildId,
          requiredPermissions: [Permissions.manageMessages],
          actionLabel: 'clear reactions',
          cache: permissionCache,
        );
        if (permError != null) {
          throw Exception(permError);
        }
      }
      final result = await clearAllReactionsAction(
        client,
        payload: resolvedPayload,
        fallbackChannelId: fallbackChannelId,
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['status'] ?? 'OK';
      return true;

    default:
      return false;
  }
}
