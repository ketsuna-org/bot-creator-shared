import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return Snowflake(parsed);
}

/// Fetches a message from [channelId] by [messageId].
///
/// Returns `{'messageId', 'content', 'authorId', 'authorUsername', 'timestamp'}`
/// or `{'error': '...'}` on failure.
Future<Map<String, String>> getMessageAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  Snowflake? fallbackChannelId,
}) async {
  try {
    final channelId = _toSnowflake(payload['channelId']) ?? fallbackChannelId;
    if (channelId == null) {
      return {'error': 'channelId is required for getMessage'};
    }

    final messageId = _toSnowflake(payload['messageId']);
    if (messageId == null) {
      return {'error': 'messageId is required for getMessage'};
    }

    final channel = await fetchChannelCached(client, channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel'};
    }

    final message = await channel.messages.get(messageId);
    return {
      'messageId': message.id.toString(),
      'content': message.content,
      'authorId': message.author.id.toString(),
      'authorUsername': message.author.username,
      'timestamp': message.timestamp.toIso8601String(),
    };
  } catch (e) {
    return {'error': 'Failed to get message: $e'};
  }
}
