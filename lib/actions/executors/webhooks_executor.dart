import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';
import '../delete_webhook.dart';
import '../edit_webhook.dart';
import '../get_webhook.dart';
import '../list_webhooks.dart';
import '../permission_checks.dart';
import '../send_webhook.dart';

Future<bool> executeWebhooksAction({
  required BotCreatorActionType type,
  required NyxxGateway client,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Snowflake? fallbackChannelId,
  required Snowflake? fallbackGuildId,
  required String Function(String input) resolveValue,
  BotPermissionCache? permissionCache,
}) async {
  switch (type) {
    case BotCreatorActionType.sendWebhook:
    case BotCreatorActionType.editWebhook:
    case BotCreatorActionType.deleteWebhook:
      final result = await switch (type) {
        BotCreatorActionType.sendWebhook => sendWebhookAction(
          client,
          payload: payload,
          resolve: resolveValue,
        ),
        BotCreatorActionType.editWebhook => editWebhookAction(
          client,
          payload: payload,
        ),
        BotCreatorActionType.deleteWebhook => deleteWebhookAction(
          client,
          payload: payload,
        ),
        _ => throw Exception('Unexpected action type'),
      };
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['webhookId'] ?? '';
      return true;

    case BotCreatorActionType.listWebhooks:
      if (fallbackGuildId != null) {
        final permError = await checkBotGuildPermission(
          client,
          guildId: fallbackGuildId,
          requiredPermissions: [Permissions.manageWebhooks],
          actionLabel: 'list webhooks',
          cache: permissionCache,
        );
        if (permError != null) {
          throw Exception(permError);
        }
      }
      final result = await listWebhooksAction(
        client,
        payload: payload,
        fallbackChannelId: fallbackChannelId,
        fallbackGuildId: fallbackGuildId,
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['webhooks'] ?? '[]';
      return true;

    case BotCreatorActionType.getWebhook:
      final result = await getWebhookAction(client, payload: payload);
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['webhook'] ?? '';
      return true;

    default:
      return false;
  }
}
