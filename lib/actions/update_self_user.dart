import 'dart:convert';
import 'package:nyxx/nyxx.dart';
import 'package:http/http.dart' as http;

/// Updates the bot's own user profile.
///
/// Payload fields:
/// - `username` — new username (optional)
/// - `avatarUrl` — URL to download new avatar from (optional)
/// - `avatarBase64` — base64 image data (optional, used if avatarUrl is empty)
///
/// Returns `{'status': 'updated', 'username', 'userId'}` or `{'error': '...'}`.
Future<Map<String, String>> updateSelfUserAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    final username = resolve((payload['username'] ?? '').toString()).trim();
    final avatarUrl = resolve((payload['avatarUrl'] ?? '').toString()).trim();
    final avatarBase64 =
        resolve((payload['avatarBase64'] ?? '').toString()).trim();

    if (username.isEmpty && avatarUrl.isEmpty && avatarBase64.isEmpty) {
      return {
        'error':
            'At least one of username, avatarUrl, or avatarBase64 must be provided',
      };
    }

    ImageBuilder? avatar;
    if (avatarBase64.isNotEmpty) {
      avatar = _imageFromBase64(avatarBase64);
    } else if (avatarUrl.isNotEmpty) {
      avatar = await _imageFromUrl(avatarUrl);
    }

    final builder = UserUpdateBuilder(
      username: username.isNotEmpty ? username : null,
      avatar: avatar,
    );

    final user = await client.users.updateCurrentUser(builder);
    return {
      'status': 'updated',
      'username': user.username,
      'userId': user.id.toString(),
    };
  } catch (e) {
    return {'error': 'Failed to update self user: $e'};
  }
}

ImageBuilder? _imageFromBase64(String base64Data) {
  try {
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
    return ImageBuilder(data: bytes, format: _mimeToFormat(mime));
  } catch (_) {
    return null;
  }
}

Future<ImageBuilder?> _imageFromUrl(String url) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;
    final contentType = response.headers['content-type'] ?? 'image/png';
    return ImageBuilder(
      data: response.bodyBytes,
      format: _mimeToFormat(contentType),
    );
  } catch (_) {
    return null;
  }
}

String _mimeToFormat(String mime) {
  if (mime.contains('jpeg') || mime.contains('jpg')) return 'jpeg';
  if (mime.contains('gif')) return 'gif';
  if (mime.contains('webp')) return 'webp';
  return 'png';
}
