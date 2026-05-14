import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';
import '../create_channel.dart';
import '../permission_checks.dart';
import '../remove_channel.dart';
import '../slowmode.dart';
import '../update_channel.dart';

Snowflake? _toSnowflake(dynamic value) {
  if (value == null) return null;
  if (value is Snowflake) return value;
  if (value is BigInt) return Snowflake(value.toInt());
  final s = value.toString().trim();
  final parsed = int.tryParse(s);
  if (parsed == null) return null;
  return Snowflake(parsed);
}

Future<bool> executeChannelsAction({
  required BotCreatorActionType type,
  required NyxxGateway client,
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required String Function(String input) resolveValue,
  BotPermissionCache? permissionCache,
}) async {
  switch (type) {
    case BotCreatorActionType.createChannel:
      if (guildId == null) {
        throw Exception('This action requires a guild context');
      }

      final Map<String, String> createResult = await createChannelAction(
        client,
        guildId: guildId,
        payload: payload,
        resolve: resolveValue,
      );

      // Robust error handling: handle non-null and empty error messages
      if ((createResult['error'] ?? '').toString().isNotEmpty) {
        throw Exception(createResult['error']);
      } else if (createResult.containsKey('error')) {
        throw Exception('Action failed with empty error message');
      }

      final channelIdValueCreate = createResult['channelId'] ?? '';
      if (resultKey.isNotEmpty) {
        results[resultKey] = channelIdValueCreate;
      }
      return true;

    case BotCreatorActionType.updateChannel:
      if (guildId != null) {
        final permError = await checkBotGuildPermission(
          client,
          guildId: guildId,
          requiredPermissions: [Permissions.manageChannels],
          actionLabel: 'update channels',
          cache: permissionCache,
        );
        if (permError != null) {
          throw Exception(permError);
        }
      }

      final Map<String, String> updateResult = await updateChannelAction(
        client,
        payload: payload,
        resolve: resolveValue,
      );

      if ((updateResult['error'] ?? '').toString().isNotEmpty) {
        throw Exception(updateResult['error']);
      } else if (updateResult.containsKey('error')) {
        throw Exception('Action failed with empty error message');
      }

      final channelIdValueUpdate = updateResult['channelId'] ?? '';
      if (resultKey.isNotEmpty) {
        results[resultKey] = channelIdValueUpdate;
      }
      return true;

    case BotCreatorActionType.removeChannel:
      if (guildId != null) {
        final permError = await checkBotGuildPermission(
          client,
          guildId: guildId,
          requiredPermissions: [Permissions.manageChannels],
          actionLabel: 'delete channels',
          cache: permissionCache,
        );
        if (permError != null) {
          throw Exception(permError);
        }
      }

      // Resolve placeholders before converting to Snowflake
      final resolvedChannelIdRaw = resolveValue(payload['channelId']?.toString() ?? '');
      final channelId = _toSnowflake(resolvedChannelIdRaw);
      if (channelId == null) {
        throw Exception('Missing or invalid channelId for removeChannel');
      }

      final Map<String, String> removeResult = await removeChannel(client, channelId);

      if ((removeResult['error'] ?? '').toString().isNotEmpty) {
        throw Exception(removeResult['error']);
      } else if (removeResult.containsKey('error')) {
        throw Exception('Action failed with empty error message');
      }

      final channelIdValueRemove = removeResult['channelId'] ?? '';
      if (resultKey.isNotEmpty) {
        results[resultKey] = channelIdValueRemove;
      }
      return true;

    case BotCreatorActionType.slowmode:
      if (guildId == null) {
        throw Exception('This action requires a guild context');
      }

      final Map<String, String> slowmodeResult = await slowmodeAction(
        client,
        guildId: guildId,
        payload: payload,
        resolve: resolveValue,
      );

      if ((slowmodeResult['error'] ?? '').toString().isNotEmpty) {
        throw Exception(slowmodeResult['error']);
      } else if (slowmodeResult.containsKey('error')) {
        throw Exception('Action failed with empty error message');
      }

      final channelIdValueSlowmode = slowmodeResult['channelId'] ?? '';
      if (resultKey.isNotEmpty) {
        results[resultKey] = channelIdValueSlowmode;
      }
      return true;

    default:
      return false;
  }
}
