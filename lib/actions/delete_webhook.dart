import 'package:nyxx/nyxx.dart';

import 'handler_utils.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

({Snowflake? id, String? token}) _extractWebhookRef(
  Map<String, dynamic> payload,
  String Function(String)? resolve,
) {
  final rawWebhookId = payload['webhookId']?.toString() ?? '';
  final webhookId = resolve != null ? resolve(rawWebhookId) : rawWebhookId;
  final directId = _toSnowflake(webhookId);
  final directToken = payload['token']?.toString().trim();

  final rawUrl = payload['webhookUrl']?.toString().trim() ?? '';
  final url = resolve != null ? resolve(rawUrl) : rawUrl;
  final uri = Uri.tryParse(url);
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

Future<Map<String, String>> deleteWebhookAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  String Function(String)? resolve,
}) async {
  // Résoudre les variables dans le payload si une fonction resolve est fournie
  final resolvedPayload = resolve != null
      ? resolvePayloadValues(payload, resolve)
      : payload;

  try {
    final ref = _extractWebhookRef(resolvedPayload, resolve);
    if (ref.id == null) {
      return {'error': 'Missing webhookId (or webhookUrl)', 'webhookId': ''};
    }

    final reason = resolvedPayload['reason']?.toString().trim();

    await client.webhooks.delete(
      ref.id!,
      token: (ref.token != null && ref.token!.isNotEmpty) ? ref.token : null,
      auditLogReason: (reason != null && reason.isNotEmpty) ? reason : null,
    );

    return {'webhookId': ref.id.toString(), 'status': 'deleted'};
  } catch (error) {
    return {'error': 'Failed to delete webhook: $error', 'webhookId': ''};
  }
}