import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:nyxx/nyxx.dart';

Future<Map<String, String>> registerGuildCommandsAction(
  NyxxGateway client, {
  required String botId,
  required BotDataStore store,
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
}) async {
  if (guildId == null) {
    return {'error': 'No guildId provided'};
  }

  final commands = await store.getCommands(botId);
  final providedCommandNames =
      (payload['commandNames'] as List<dynamic>?)
          ?.map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList() ??
      [];

  final matchingCommands = commands.where((cmd) {
    final type = cmd['type']?.toString();
    if (type != 'chatInput') return false;

    final rawData = cmd['data'];
    final data = (rawData is Map)
        ? Map<String, dynamic>.from(rawData.cast<String, dynamic>())
        : <String, dynamic>{};

    // Only fetch commands marked as localOnly.
    if (data['legacyLocalOnly'] != true) return false;

    final name = cmd['name']?.toString() ?? '';
    if (providedCommandNames.isNotEmpty) {
      if (!providedCommandNames.contains(name)) return false;
    }
    return true;
  }).toList();

  for (final cmd in matchingCommands) {
    final name = cmd['name']?.toString() ?? '';
    final description =
        cmd['description']?.toString() ?? 'No description provided';

    final rawData = cmd['data'];
    final data = (rawData is Map)
        ? Map<String, dynamic>.from(rawData.cast<String, dynamic>())
        : <String, dynamic>{};

    final optionsRaw = data['options'] as List<dynamic>? ?? [];

    final options = optionsRaw.map((opt) {
      final oMap = (opt is Map<String, dynamic>) ? opt : <String, dynamic>{};
      return CommandOptionBuilder(
        type: CommandOptionType(oMap['type'] as int? ?? 3),
        name: oMap['name']?.toString() ?? '',
        description: oMap['description']?.toString() ?? '',
        isRequired: oMap['required'] == true,
      );
    }).toList();

    try {
      await client.guilds[guildId].commands.create(
        ApplicationCommandBuilder.chatInput(
          name: name,
          description: description,
          options: options,
        ),
      );
    } catch (e) {
      return {'error': 'Failed to register $name: $e'};
    }
  }

  return {'status': 'OK', 'registered': matchingCommands.length.toString()};
}
