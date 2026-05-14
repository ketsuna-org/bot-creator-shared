import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:nyxx/nyxx.dart';

Future<Map<String, String>> unregisterGuildCommandsAction(
  NyxxGateway client, {
  required String botId,
  required BotDataStore store,
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
}) async {
  if (guildId == null) {
    return {'error': 'No guildId provided'};
  }

  final providedCommandNames =
      (payload['commandNames'] as List<dynamic>?)
          ?.map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList() ??
      [];

  try {
    final commandManager = client.guilds[guildId].commands;
    final currentCommands = await commandManager.list();

    int unregisteredCount = 0;

    for (final cmd in currentCommands) {
      if (providedCommandNames.isEmpty ||
          providedCommandNames.contains(cmd.name)) {
        await commandManager.delete(cmd.id);
        unregisteredCount++;
      }
    }

    return {'status': 'OK', 'unregistered': unregisteredCount.toString()};
  } catch (e) {
    return {'error': 'Failed to unregister commands: $e'};
  }
}
