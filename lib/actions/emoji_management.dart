import 'dart:convert';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'package:http/http.dart' as http;
import 'permission_checks.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return Snowflake(parsed);
}

List<Snowflake> _toSnowflakeList(dynamic value) {
  if (value == null) return [];
  List<String> raw;
  if (value is List) {
    raw = value.map((e) => e.toString().trim()).toList();
  } else {
    final s = value.toString().trim();
    if (s.isEmpty) return [];
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) {
        raw = decoded.map((e) => e.toString().trim()).toList();
      } else {
        raw = s.split(',').map((e) => e.trim()).toList();
      }
    } catch (_) {
      raw = s.split(',').map((e) => e.trim()).toList();
    }
  }
  return raw.map(_toSnowflake).whereType<Snowflake>().toList();
}

/// Downloads image bytes from [url] and encodes as a data URI (base64).
Future<ImageBuilder?> _imageFromUrl(String url) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;
    final bytes = response.bodyBytes;
    final contentType = response.headers['content-type'] ?? 'image/png';
    return ImageBuilder(data: bytes, format: _extensionForMime(contentType));
  } catch (_) {
    return null;
  }
}

String _extensionForMime(String mime) {
  if (mime.contains('jpeg') || mime.contains('jpg')) return 'jpeg';
  if (mime.contains('gif')) return 'gif';
  if (mime.contains('webp')) return 'webp';
  return 'png';
}

ImageBuilder? _imageFromBase64(String base64Data) {
  try {
    // Accept both raw base64 and data URIs
    String raw = base64Data.trim();
    String mime = 'image/png';
    if (raw.startsWith('data:')) {
      final semiColon = raw.indexOf(';');
      final comma = raw.indexOf(',');
      if (semiColon > 0 && comma > semiColon) {
        mime = raw.substring(5, semiColon);
        raw = raw.substring(comma + 1);
      }
    }
    final bytes = base64Decode(raw);
    return ImageBuilder(data: bytes, format: _extensionForMime(mime));
  } catch (_) {
    return null;
  }
}

/// Creates a new emoji in a guild.
///
/// Payload fields:
/// - `name` — emoji name (required, alphanumeric + underscores)
/// - `imageBase64` — base64 image data (or data URI) — if provided, used directly
/// - `imageUrl` — URL to download image from (used if imageBase64 is empty)
/// - `roles` — JSON array of role IDs that can use this emoji (optional)
/// - `reason` — audit log reason
///
/// Returns `{'emojiId', 'name', 'status': 'created'}` or `{'error': '...'}`.
Future<Map<String, String>> createEmojiAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'createEmoji requires a guild context'};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.manageGuildExpressions],
      actionLabel: 'manage emojis',
    );
    if (permError != null) {
      return {'error': permError};
    }

    final name = resolve((payload['name'] ?? '').toString()).trim();
    if (name.isEmpty) {
      return {'error': 'name is required for createEmoji'};
    }

    final base64Raw = resolve((payload['imageBase64'] ?? '').toString()).trim();
    final urlRaw = resolve((payload['imageUrl'] ?? '').toString()).trim();

    ImageBuilder? image;
    if (base64Raw.isNotEmpty) {
      image = _imageFromBase64(base64Raw);
    } else if (urlRaw.isNotEmpty) {
      image = await _imageFromUrl(urlRaw);
    }

    if (image == null) {
      return {
        'error':
            'Either imageBase64 or imageUrl must be provided for createEmoji',
      };
    }

    final roles = _toSnowflakeList(payload['roles']);
    final reason = resolve((payload['reason'] ?? '').toString()).trim();

    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found'};
    final emoji = await guild.emojis.create(
      EmojiBuilder(name: name, image: image, roles: roles),
      auditLogReason: reason.isNotEmpty ? reason : null,
    );

    return {
      'emojiId': emoji.id.toString(),
      'name': emoji.name ?? name,
      'status': 'created',
    };
  } catch (e) {
    return {'error': 'Failed to create emoji: $e'};
  }
}

/// Updates an existing guild emoji.
///
/// Payload fields:
/// - `emojiId` — emoji to update (required)
/// - `name` — new emoji name
/// - `roles` — new role IDs allowed to use the emoji (JSON array or comma-separated)
/// - `reason` — audit log reason
///
/// Returns `{'emojiId', 'name', 'status': 'updated'}` or `{'error': '...'}`.
Future<Map<String, String>> updateEmojiAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'updateEmoji requires a guild context'};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.manageGuildExpressions],
      actionLabel: 'manage emojis',
    );
    if (permError != null) {
      return {'error': permError};
    }

    final emojiId = _toSnowflake(
      resolve((payload['emojiId'] ?? '').toString()),
    );
    if (emojiId == null) {
      return {'error': 'emojiId is required for updateEmoji'};
    }

    final name = resolve((payload['name'] ?? '').toString()).trim();
    final roles = _toSnowflakeList(payload['roles']);
    final reason = resolve((payload['reason'] ?? '').toString()).trim();

    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found'};
    final builder = EmojiUpdateBuilder(
      name: name.isNotEmpty ? name : null,
      roles: roles.isEmpty ? null : roles,
    );
    final emoji = await guild.emojis.update(
      emojiId,
      builder,
      auditLogReason: reason.isNotEmpty ? reason : null,
    );

    return {
      'emojiId': emoji.id.toString(),
      'name': emoji.name ?? '',
      'status': 'updated',
    };
  } catch (e) {
    return {'error': 'Failed to update emoji: $e'};
  }
}

/// Deletes a guild emoji.
///
/// Payload fields:
/// - `emojiId` — emoji to delete (required)
/// - `reason` — audit log reason
///
/// Returns `{'emojiId', 'status': 'deleted'}` or `{'error': '...'}`.
Future<Map<String, String>> deleteEmojiAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'deleteEmoji requires a guild context'};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.manageGuildExpressions],
      actionLabel: 'manage emojis',
    );
    if (permError != null) {
      return {'error': permError};
    }

    final emojiId = _toSnowflake(
      resolve((payload['emojiId'] ?? '').toString()),
    );
    if (emojiId == null) {
      return {'error': 'emojiId is required for deleteEmoji'};
    }

    final reason = resolve((payload['reason'] ?? '').toString()).trim();

    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found'};
    await guild.emojis.delete(
      emojiId,
      auditLogReason: reason.isNotEmpty ? reason : null,
    );

    return {'emojiId': emojiId.toString(), 'status': 'deleted'};
  } catch (e) {
    return {'error': 'Failed to delete emoji: $e'};
  }
}
