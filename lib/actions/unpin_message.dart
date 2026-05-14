import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return Snowflake(parsed);
}

/// Unpins a message from a channel.
///
/// Returns `{'messageId', 'status': 'unpinned'}` or `{'error': '...'}`.
Future<Map<String, String>> unpinMessageAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  Snowflake? fallbackChannelId,
}) async {
  try {
    final channelId = _toSnowflake(payload['channelId']) ?? fallbackChannelId;
    if (channelId == null) {
      return {'error': 'channelId is required for unpinMessage'};
    }

    final messageId = _toSnowflake(payload['messageId']);
    if (messageId == null) {
      return {'error': 'messageId is required for unpinMessage'};
    }

    final channel = await fetchChannelCached(client, channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel'};
    }

    await channel.messages[messageId].unpin(
      auditLogReason:
          (payload['reason']?.toString().trim().isNotEmpty == true)
              ? payload['reason'].toString().trim()
              : null,
    );
    return {'messageId': messageId.toString(), 'status': 'unpinned'};
  } catch (e) {
    return {'error': 'Failed to unpin message: $e'};
  }
}
