import 'package:nyxx/nyxx.dart';
import '../types/component.dart';
import 'send_component_v2.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

({Snowflake? id, String? token}) _extractWebhookRef(
  String webhookUrl,
  String webhookId,
  String token,
) {
  final directId = _toSnowflake(webhookId);
  final directToken = token.trim();

  if (directId != null && directToken.isNotEmpty) {
    return (id: directId, token: directToken);
  }

  final uri = Uri.tryParse(webhookUrl.trim());
  if (uri == null) {
    return (id: directId, token: directToken);
  }

  final segments = uri.pathSegments;
  final webhooksIndex = segments.indexOf('webhooks');
  if (webhooksIndex == -1 || webhooksIndex + 2 >= segments.length) {
    return (id: directId, token: directToken);
  }

  final parsedId = _toSnowflake(segments[webhooksIndex + 1]);
  final parsedToken = segments[webhooksIndex + 2].trim();

  return (
    id: parsedId ?? directId,
    token: parsedToken.isNotEmpty ? parsedToken : directToken,
  );
}

Future<Map<String, String>> sendWebhookAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  String Function(String)? resolve,
}) async {
  resolve ??= (s) => s;
  try {
    final webhookUrl = resolve((payload['webhookUrl'] ?? '').toString()).trim();
    final webhookId = resolve((payload['webhookId'] ?? '').toString()).trim();
    final token = resolve((payload['token'] ?? '').toString()).trim();
    final ref = _extractWebhookRef(webhookUrl, webhookId, token);
    if (ref.id == null || ref.token == null || ref.token!.isEmpty) {
      return {
        'error': 'Missing webhookId/token (or webhookUrl)',
        'messageId': '',
      };
    }

    final content = resolve((payload['content'] ?? '').toString());
    final username = resolve((payload['username'] ?? '').toString()).trim();
    final avatarUrl = resolve((payload['avatarUrl'] ?? '').toString()).trim();
    final waitRaw = resolve((payload['wait'] ?? '').toString());
    final wait =
        payload['wait'] is bool
            ? payload['wait'] as bool
            : waitRaw.toLowerCase() == 'true';
    final threadId = _toSnowflake(
      resolve((payload['threadId'] ?? '').toString()),
    );

    List<ComponentBuilder>? components;
    bool isRichV2 = false;
    final componentPayload = payload['componentV2'] ?? payload['components'];
    if (componentPayload is Map) {
      try {
        final def = ComponentV2Definition.fromJson(
          Map<String, dynamic>.from(componentPayload),
        );
        isRichV2 = def.isRichV2;
        components = buildComponentNodes(definition: def, resolve: resolve);
      } catch (_) {}
    }

    final message = await client.webhooks.execute(
      ref.id!,
      MessageBuilder(
        content: content.isNotEmpty ? content : null,
        components: components,
        flags: isRichV2 ? MessageFlags(32768) : null,
      ),
      token: ref.token!,
      wait: wait,
      threadId: threadId,
      username: username.isNotEmpty ? username : null,
      avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
    );

    return {
      'messageId': message?.id.toString() ?? '',
      'webhookId': ref.id.toString(),
      'status': wait ? 'sent' : 'queued',
    };
  } catch (error) {
    return {'error': 'Failed to send webhook message: $error', 'messageId': ''};
  }
}
