import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'package:bot_creator_shared/types/component.dart';
import 'package:bot_creator_shared/utils/component_workflow_bindings.dart';

import 'send_component_v2.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, dynamic>> editComponentV2Action(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  Snowflake? fallbackChannelId,
  String Function(String)? resolve,
  String? botId,
  String? guildId,
}) async {
  resolve ??= (s) => s;
  try {
    final definition =
        (payload['components'] ?? payload['componentV2']) is Map
            ? ComponentV2Definition.fromJson(
              Map<String, dynamic>.from(
                (payload['components'] ?? payload['componentV2']) as Map,
              ),
            )
            : ComponentV2Definition();

    final channelId =
        _toSnowflake(resolve((payload['channelId'] ?? '').toString())) ??
        fallbackChannelId;
    final messageId = _toSnowflake(
      resolve((payload['messageId'] ?? '').toString()),
    );
    if (channelId == null || messageId == null) {
      return {'error': 'Missing channelId/messageId', 'messageId': ''};
    }

    final channel = await fetchChannelCached(client, channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel', 'messageId': ''};
    }

    final message = await channel.messages.fetch(messageId);
    final components = buildComponentNodes(
      definition: definition,
      resolve: resolve,
    );

    await message.edit(MessageUpdateBuilder(components: components));
    if (botId != null && botId.trim().isNotEmpty) {
      registerComponentWorkflowBindings(
        definition: definition,
        resolve: resolve,
        botId: botId,
        guildId: guildId,
        channelId: channelId.toString(),
        messageId: message.id.toString(),
      );
    }

    return {'messageId': message.id.toString()};
  } catch (error) {
    return {'error': 'Failed to edit Component V2 message: $error'};
  }
}
