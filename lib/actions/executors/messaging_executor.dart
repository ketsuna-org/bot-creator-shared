import 'dart:async';
import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';
import '../../utils/bdfd_duration_parser.dart';
import '../delete_message.dart';
import '../edit_message.dart';
import '../get_message.dart';
import '../permission_checks.dart';
import '../send_message.dart';

Snowflake? _toSnowflake(dynamic value) {
  if (value == null) {
    return null;
  }

  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    return null;
  }

  return Snowflake(parsed);
}

Future<bool> executeMessagingAction({
  required BotCreatorActionType type,
  required NyxxGateway client,
  required Interaction? interaction,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String botId,
  required Snowflake? guildId,
  required Snowflake? fallbackChannelId,
  required String Function(String input) resolveValue,
  BotPermissionCache? permissionCache,
}) async {
  switch (type) {
    case BotCreatorActionType.deleteMessages:
      if (guildId != null) {
        final permError = await checkBotGuildPermission(
          client,
          guildId: guildId,
          requiredPermissions: [
            Permissions.manageMessages,
            Permissions.readMessageHistory,
          ],
          actionLabel: 'delete messages',
          cache: permissionCache,
        );
        if (permError != null) {
          throw Exception(permError);
        }
      }
      final resolvedChannelIdRaw = resolveValue(
        (payload['channelId'] ?? '').toString(),
      );
      final channelId = _toSnowflake(resolvedChannelIdRaw) ?? fallbackChannelId;
      if (channelId == null) {
        throw Exception('Missing or invalid channelId for deleteMessages');
      }

      final resolvedMessageIdRaw = resolveValue(
        (payload['messageId'] ?? '').toString(),
      );
      final messageId = _toSnowflake(resolvedMessageIdRaw);

      final delayRaw = resolveValue((payload['delay'] ?? '').toString());
      final delayDuration = delayRaw.isNotEmpty ? parseBdfdDuration(delayRaw) : null;

      final rawCount = payload['messageCount'] ?? payload['count'];
      final resolvedCountRaw = resolveValue((rawCount ?? '').toString());
      final parsedCount = double.tryParse(resolvedCountRaw);
      final count =
          parsedCount != null
              ? parsedCount.round()
              : (rawCount is num ? rawCount.toInt() : (messageId != null ? 1 : 0));

      final onlyUserId = resolveValue((payload['onlyUserId'] ?? '').toString());
      final reason = resolveValue((payload['reason'] ?? '').toString()).trim();

      final filterBotsRaw =
          resolveValue((payload['filterBots'] ?? '').toString()).toLowerCase();
      final filterUsersRaw =
          resolveValue((payload['filterUsers'] ?? '').toString()).toLowerCase();
      final filterBots = filterBotsRaw == 'true' || filterBotsRaw == '1';
      final filterUsers = filterUsersRaw == 'true' || filterUsersRaw == '1';

      final removePinnedRaw = resolveValue(
        (payload['removePinned'] ?? '').toString(),
      ).toLowerCase();
      var deletePinned = true;
      if (removePinnedRaw.isNotEmpty) {
        if (removePinnedRaw == 'no' ||
            removePinnedRaw == 'false' ||
            removePinnedRaw == '0' ||
            removePinnedRaw == 'n') {
          deletePinned = false;
        }
      }

      final beforeRaw = resolveValue(
        (payload['beforeMessageId'] ?? '').toString(),
      );
      final beforeMessageId = _toSnowflake(beforeRaw);

      final deleteItselfRaw =
          resolveValue(
            (payload['deleteItself'] ?? '').toString(),
          ).toLowerCase();
      var deleteItself = false;
      if (deleteItselfRaw.isNotEmpty) {
        if (deleteItselfRaw == 'true' ||
            deleteItselfRaw == 'yes' ||
            deleteItselfRaw == 'y' ||
            deleteItselfRaw == '1') {
          deleteItself = true;
        } else {
          final numVal = num.tryParse(deleteItselfRaw);
          if (numVal != null && numVal > 0) {
            deleteItself = true;
          }
        }
      }

      Snowflake? commandMessageId;
      try {
        if (interaction is ApplicationCommandInteraction) {
          final resp = await interaction.fetchOriginalResponse();
          commandMessageId = resp.id;
        }
      } catch (_) {}

      if (delayDuration != null) {
        Timer(delayDuration, () async {
          try {
            if (messageId != null) {
              final channel = client.channels[channelId];
              if (channel is PartialTextChannel) {
                await channel.messages[messageId].delete();
              }
            } else {
              await deleteMessage(
                client,
                channelId,
                count: count,
                onlyThisUserID: onlyUserId,
                beforeMessageId: beforeMessageId,
                deleteItself: deleteItself,
                commandMessageId: commandMessageId,
                filterBots: filterBots,
                filterUsers: filterUsers,
                reason: reason,
                deletePinned: deletePinned,
              );
            }
          } catch (_) {
            // Keep delayed deletion silent and resilient
          }
        });
        results[resultKey] = 'scheduled';
        variables['action.$resultKey.status'] = 'scheduled';
        return true;
      }

      if (messageId != null) {
        try {
          final channel = client.channels[channelId];
          if (channel is PartialTextChannel) {
            await channel.messages[messageId].delete();
            results[resultKey] = '1';
            variables['action.$resultKey.count'] = '1';
            variables['$resultKey.count'] = '1';
            variables['action.$resultKey.mode'] = 'single';
            variables['$resultKey.mode'] = 'single';
            return true;
          } else {
            throw Exception('Channel is not a text channel');
          }
        } catch (e) {
          throw Exception('Failed to delete specific message: $e');
        }
      }

      final result = await deleteMessage(
        client,
        channelId,
        count: count,
        onlyThisUserID: onlyUserId,
        beforeMessageId: beforeMessageId,
        deleteItself: deleteItself,
        commandMessageId: commandMessageId,
        filterBots: filterBots,
        filterUsers: filterUsers,
        reason: reason,
        deletePinned: deletePinned,
      );
      if (result['error'] != null) {
        final errorCode = result['errorCode'];
        if (errorCode != null && errorCode.isNotEmpty) {
          throw Exception('[$errorCode] ${result['error']}');
        }
        throw Exception(result['error']);
      }
      final deletedCount = result['count'] ?? '0';
      results[resultKey] = deletedCount;
      variables['action.$resultKey.count'] = deletedCount;
      variables['$resultKey.count'] = deletedCount;
      final deleteMode = result['mode'] ?? 'none';
      variables['action.$resultKey.mode'] = deleteMode;
      variables['$resultKey.mode'] = deleteMode;
      if (deleteItself) {
        variables['action.$resultKey.deleteItself'] = deleteItself.toString();
        variables['$resultKey.deleteItself'] = deleteItself.toString();
        variables['action.$resultKey.deleteResponse'] = deleteItself.toString();
        variables['$resultKey.deleteResponse'] = deleteItself.toString();
      }
      return true;

    case BotCreatorActionType.sendMessage:
      final targetType =
          (payload['targetType'] ?? 'channel').toString().trim().toLowerCase();
      final channelId = _toSnowflake(resolveValue((payload['channelId'] ?? '').toString())) ?? fallbackChannelId;

      if (targetType != 'user' && guildId != null) {
        final permError = await checkBotGuildPermission(
          client,
          guildId: guildId,
          requiredPermissions: [Permissions.sendMessages],
          actionLabel: 'send messages',
          cache: permissionCache,
        );
        if (permError != null) {
          throw Exception(permError);
        }
      }

      if (targetType != 'user' && channelId == null) {
        throw Exception('Missing or invalid channelId for sendMessage');
      }

      final content = resolveValue((payload['content'] ?? '').toString());

      final resolvedSendPayload = Map<String, dynamic>.from(payload);
      if (targetType == 'user') {
        resolvedSendPayload['userId'] = resolveValue(
          (payload['userId'] ?? '').toString(),
        );
      }
      
      // Resolve messageId if present (important for replies)
      if (payload.containsKey('messageId')) {
        resolvedSendPayload['messageId'] = resolveValue(
          (payload['messageId'] ?? '').toString(),
        );
      }

      final result = await sendMessageToChannel(
        client,
        channelId,
        content: content,
        payload: resolvedSendPayload,
        resolve: resolveValue,
        botId: botId,
        guildId: guildId?.toString(),
      );
      if (result['error'] != null) {
        // When content/embeds/components are all empty (e.g. template resolved
        // to blank inside a loop iteration), skip silently instead of crashing.
        if (content.trim().isEmpty &&
            result['error']!.contains('needs at least')) {
          results[resultKey] = '';
          return true;
        }
        throw Exception(result['error']);
      }
      results[resultKey] = result['messageId'] ?? '';
      variables['$resultKey.messageId'] = result['messageId'] ?? '';
      return true;

    case BotCreatorActionType.editMessage:
      final content = resolveValue((payload['content'] ?? '').toString());
      final result = await editMessageAction(
        client,
        payload: payload,
        fallbackChannelId: fallbackChannelId,
        content: content,
        resolve: resolveValue,
        botId: botId,
        guildId: guildId?.toString(),
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['messageId'] ?? '';
      return true;

    case BotCreatorActionType.getMessage:
      final result = await getMessageAction(
        client,
        payload: payload,
        fallbackChannelId: fallbackChannelId,
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['messageId'] ?? '';
      for (final entry in result.entries) {
        variables['$resultKey.${entry.key}'] = entry.value;
      }
      return true;

    case BotCreatorActionType.deleteTrigger:
      // Try to find the trigger message ID from variables or interaction
      final triggerMessageIdRaw = variables['message.id'] ??
          variables['author.message.id'] ??
          variables['messageId'] ??
          '';
      final triggerChannelIdRaw = variables['channel.id'] ??
          variables['channelId'] ??
          variables['message.channelId'] ??
          '';
      final triggerMessageId = _toSnowflake(triggerMessageIdRaw);
      final triggerChannelId = _toSnowflake(triggerChannelIdRaw) ?? fallbackChannelId;

      if (triggerMessageId != null && triggerChannelId != null) {
        try {
          final channel = client.channels[triggerChannelId];
          if (channel is PartialTextChannel) {
            await channel.messages[triggerMessageId].delete();
            results[resultKey] = triggerMessageId.toString();
          } else {
            results[resultKey] = 'INVALID_CHANNEL';
          }
        } catch (e) {
          results[resultKey] = 'ERROR';
          // Skip error to avoid stopping workflow if message was already deleted or perms missing
        }
      } else {
        results[resultKey] = 'NOT_FOUND';
      }
      return true;
    case BotCreatorActionType.sendDm:
      final userId = resolveValue((payload['userId'] ?? '').toString());
      final content = resolveValue((payload['content'] ?? '').toString());
      if (userId.isEmpty) {
        throw Exception('Missing userId for sendDm');
      }

      final dmPayload = Map<String, dynamic>.from(payload)
        ..['targetType'] = 'user'
        ..['userId'] = userId
        ..['content'] = content;

      final result = await sendMessageToChannel(
        client,
        null,
        content: content,
        payload: dmPayload,
        resolve: resolveValue,
        botId: botId,
        guildId: guildId?.toString(),
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['messageId'] ?? '';
      variables['$resultKey.messageId'] = result['messageId'] ?? '';
      return true;

    case BotCreatorActionType.deferInteraction:
      if (interaction == null) {
        // No interaction context — nothing to defer.
        results[resultKey] = 'skipped';
        return true;
      }
      final ephemeralRaw = payload['ephemeral'];
      final deferEphemeral =
          ephemeralRaw == true ||
          ephemeralRaw?.toString().toLowerCase() == 'true';
      try {
        await (interaction as dynamic).acknowledge(isEphemeral: deferEphemeral);
        results[resultKey] = 'deferred';
        variables['action.$resultKey.status'] = 'deferred';
      } catch (e) {
        // If acknowledgement fails (e.g. already acknowledged), continue silently.
        results[resultKey] = 'skipped';
        variables['action.$resultKey.status'] = 'skipped';
      }
      return true;

    default:
      return false;
  }
}
