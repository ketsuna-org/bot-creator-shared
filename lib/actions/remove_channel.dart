import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';

Future<Map<String, String>> removeChannel(
  NyxxGateway client,
  Snowflake channelId,
) async {
  try {
    final channel = await fetchChannelCached(client, channelId);
    if (channel == null) return {'error': 'Channel not found', 'channelId': ''};

    await channel.delete();

    return {"channelId": channel.id.toString()};
  } catch (e) {
    return {"error": "Failed to delete channel: $e", "channelId": ""};
  }
}
