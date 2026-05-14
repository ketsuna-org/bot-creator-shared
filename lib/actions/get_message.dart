import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';

Snowflake? _toSnowflake(dynamic value) {
  if (value == null) return null;
  if (value is Snowflake) return value;
  final s = value.toString();
  final parsedInt = int.tryParse(s);
  if (parsedInt != null) return Snowflake(parsedInt);
  try {
    final big = BigInt.parse(s);
    return Snowflake(big.toInt());
  } catch (_) {
    return null;
  }
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

    final content = message.content;
    final author = message.author;
    final authorId = author.id.toString();
    final authorUsername = author.username;

    return {
      'messageId': message.id.toString(),
      'content': content,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'timestamp': message.timestamp.toIso8601String(),
    };
  } catch (e) {
    return {'error': 'Failed to get message: $e'};
  }
}
