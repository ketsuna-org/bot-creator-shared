import 'dart:async';

import 'package:bot_creator_shared/actions/action_runtime.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'package:nyxx/nyxx.dart';

Future<Map<String, String>> deleteMessage(
  NyxxGateway client,
  Snowflake channelId, {
  required int count,
  String onlyThisUserID = '',
  Snowflake? beforeMessageId,
  bool deleteItself = false,
  Snowflake? commandMessageId,
  bool filterBots = false,
  bool filterUsers = false,
  String reason = '',
  bool deletePinned = true,
}) async {
  try {
    if (count <= 0) {
      return actionError(
        code: 'invalid_count',
        message: 'Count must be greater than 0',
        data: {'count': '0'},
      );
    }

    final channel = await runWithTimeout(
      () => fetchChannelCached(client, channelId),
    );
    if (channel is! TextChannel) {
      return actionError(
        code: 'invalid_channel_type',
        message: 'Channel is not a text channel',
        data: {'count': '0'},
      );
    }

    final candidates = <Message>[];
    final seenIds = <Snowflake>{};
    Snowflake? cursor = beforeMessageId;

    while (candidates.length < count) {
      final remaining = count - candidates.length;
      final fetchLimit = remaining > 100 ? 100 : remaining;
      final fetched = await runWithTimeout(
        () => channel.messages.fetchMany(limit: fetchLimit, before: cursor),
      );
      if (fetched.isEmpty) {
        break;
      }

      for (final message in fetched) {
        if (!seenIds.add(message.id)) {
          continue;
        }

        final author = message.author;
        final isBotAuthor = author is User ? author.isBot : false;
        final filterOnlyBots = filterBots && !filterUsers;
        final filterOnlyUsers = filterUsers && !filterBots;
        if (filterOnlyBots && !isBotAuthor) {
          continue;
        }
        if (filterOnlyUsers && isBotAuthor) {
          continue;
        }
        if (onlyThisUserID.isNotEmpty &&
            message.author.id.toString() != onlyThisUserID) {
          continue;
        }
        if (!deletePinned && message.isPinned) {
          continue;
        }
        if (!deleteItself &&
            commandMessageId != null &&
            message.id == commandMessageId) {
          continue;
        }
        if (!deleteItself &&
            beforeMessageId != null &&
            message.id == beforeMessageId) {
          continue;
        }

        candidates.add(message);
        if (candidates.length >= count) {
          break;
        }
      }

      cursor = fetched.last.id;
      if (fetched.length < fetchLimit) {
        break;
      }
    }

    if (deleteItself &&
        beforeMessageId != null &&
        !seenIds.contains(beforeMessageId)) {
      try {
        final selfMessage = await runWithTimeout(
          () => channel.messages.fetch(beforeMessageId),
        );
        candidates.add(selfMessage);
      } catch (_) {
        // Ignore when message cannot be found.
      }
    }

    if (candidates.isEmpty) {
      return {"count": "0", "mode": "none"};
    }

    Future<int> deleteIndividually(List<Message> messages) async {
      var deleted = 0;
      for (final message in messages) {
        try {
          await runWithTimeout(() => message.delete());
          deleted++;
        } catch (_) {
          // Keep deletion resilient: continue with remaining messages.
        }
      }
      return deleted;
    }

    final recentIds = <Snowflake>[];
    final olderCandidates = <Message>[];
    final unique = <Snowflake>{};
    final cutoff = DateTime.now().subtract(const Duration(days: 14));

    for (final message in candidates) {
      if (!unique.add(message.id)) {
        continue;
      }
      if (message.timestamp.isAfter(cutoff)) {
        recentIds.add(message.id);
      } else {
        olderCandidates.add(message);
      }
    }

    if (unique.isEmpty) {
      return {"count": "0", "mode": "none"};
    }

    var totalDeleted = 0;

    // 1. Bulk delete recent messages in chunks of 100
    if (recentIds.isNotEmpty) {
      try {
        for (var i = 0; i < recentIds.length; i += 100) {
          final chunk = recentIds.sublist(
            i,
            i + 100 > recentIds.length ? recentIds.length : i + 100,
          );
          if (chunk.length >= 2) {
            await runWithTimeout(() => channel.messages.bulkDelete(chunk));
            totalDeleted += chunk.length;
          } else if (chunk.length == 1) {
            // A single recent message goes to olderCandidates to be deleted individually
            final msg = candidates.firstWhere((m) => m.id == chunk[0]);
            olderCandidates.add(msg);
          }
        }
      } catch (_) {
        // Fallback for remaining recent messages to delete them individually
        final deletedSoFar = totalDeleted;
        final failedRecent = recentIds
            .skip(deletedSoFar)
            .map((id) => candidates.firstWhere((m) => m.id == id));
        olderCandidates.addAll(failedRecent);
      }
    }

    // 2. Delete the rest individually
    if (olderCandidates.isNotEmpty) {
      final deleted = await deleteIndividually(olderCandidates);
      totalDeleted += deleted;
    }

    return {
      "count": totalDeleted.toString(),
      "mode": olderCandidates.isEmpty ? "bulk" : "mixed"
    };
  } on TimeoutException {
    return actionError(
      code: 'network_timeout',
      message: 'Delete messages action timed out',
      data: {'count': '0'},
    );
  } catch (e) {
    return actionError(
      code: 'delete_messages_failed',
      message: 'Failed to delete messages',
      data: {'count': '0'},
    );
  }
}
