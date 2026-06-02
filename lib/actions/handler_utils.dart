import 'package:nyxx/nyxx.dart';

/// Helper pour exÃ©cuter une action simple et rÃ©cupÃ©rer un rÃ©sultat
Future<Map<String, String>> executeSimpleAction(
  Future<Map<String, String>> Function() action,
) async {
  try {
    return await action();
  } catch (error) {
    return {'error': 'Action failed: $error'};
  }
}

/// Helper pour exÃ©cuter une action avec validation de rÃ©sultat
void validateActionResult(
  Map<String, String> result, {
  required Function(String) onError,
}) {
  if (result['error'] != null) {
    onError(result['error'] ?? 'Unknown error');
  }
}

/// Helper pour les actions sans guildId
Future<Map<String, String>> executeActionWithoutGuild(
  Future<Map<String, String>> Function() action,
) => action();

/// Helper pour les actions avec guildId
Future<Map<String, String>> executeActionWithGuild(
  Future<Map<String, String>> Function() action, {
  required Snowflake? guildId,
  String errorMessage = 'This action requires a guild context',
}) {
  if (guildId == null) {
    return Future.value({'error': errorMessage});
  }
  return action();
}

/// Helper pour les actions avec channelId
Future<Map<String, String>> executeActionWithChannel(
  Future<Map<String, String>> Function() action, {
  required Snowflake? channelId,
  String errorMessage = 'Missing or invalid channelId',
}) {
  if (channelId == null) {
    return Future.value({'error': errorMessage});
  }
  return action();
}

/// Helper pour résoudre les valeurs de chaîne dans un payload
Map<String, dynamic> resolvePayloadValues(
  Map<String, dynamic> payload,
  String Function(String) resolve,
) {
  final resolved = <String, dynamic>{};
  for (final entry in payload.entries) {
    final value = entry.value;
    if (value is String) {
      resolved[entry.key] = resolve(value);
    } else if (value is Map<String, dynamic>) {
      resolved[entry.key] = resolvePayloadValues(value, resolve);
    } else if (value is List) {
      resolved[entry.key] = value.map((item) {
        if (item is String) {
          return resolve(item);
        } else if (item is Map<String, dynamic>) {
          return resolvePayloadValues(item, resolve);
        }
        return item;
      }).toList();
    } else {
      resolved[entry.key] = value;
    }
  }
  return resolved;
}

/// Extension pour simplifier l'accès aux résultats
extension ActionResultExtension on Map<String, String> {
  bool get hasError => containsKey('error');
  String? get error => this['error'];
  String getOrEmpty(String key) => this[key] ?? '';
}

Snowflake? parseSnowflake(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  if (s.isEmpty) return null;
  final parsed = int.tryParse(s);
  if (parsed == null) return null;
  return Snowflake(parsed);
}
