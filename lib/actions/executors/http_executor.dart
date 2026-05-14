import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../types/action.dart';

// ─── Private helpers ─────────────────────────────────────────────────────────

dynamic _extractByJsonPath(dynamic data, String rawPath) {
  var path = rawPath.trim();
  if (path.isEmpty) return null;

  if (path.startsWith(r'$.')) {
    path = path.substring(2);
  } else if (path.startsWith(r'$')) {
    path = path.substring(1);
  }

  if (path.isEmpty) return data;

  final segments = <Object>[];
  final token = StringBuffer();

  void flushToken() {
    if (token.isNotEmpty) {
      segments.add(token.toString());
      token.clear();
    }
  }

  for (var i = 0; i < path.length; i++) {
    final char = path[i];
    if (char == '.') {
      flushToken();
      continue;
    }
    if (char == '[') {
      flushToken();
      final closing = path.indexOf(']', i + 1);
      if (closing == -1) return null;
      final indexText = path.substring(i + 1, closing).trim();
      final index = int.tryParse(indexText);
      if (index == null) return null;
      segments.add(index);
      i = closing;
      continue;
    }
    token.write(char);
  }
  flushToken();

  dynamic current = data;
  for (final segment in segments) {
    if (segment is String) {
      if (segment.isEmpty) continue;
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return null;
      }
      continue;
    }
    if (segment is int) {
      if (current is List && segment >= 0 && segment < current.length) {
        current = current[segment];
      } else {
        return null;
      }
    }
  }

  return current;
}

String _normalizeMethod(
  dynamic rawMethod,
  String Function(String) resolveValue,
) {
  final method =
      resolveValue(rawMethod?.toString() ?? 'GET').trim().toUpperCase();
  const supported = {'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD'};
  if (!supported.contains(method)) return 'GET';
  return method;
}

bool _supportsBody(String method) => method != 'GET' && method != 'HEAD';

dynamic _resolveJsonLike(dynamic value, String Function(String) resolveValue) {
  if (value is String) return resolveValue(value);
  if (value is List) {
    return value.map((e) => _resolveJsonLike(e, resolveValue)).toList();
  }
  if (value is Map) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map(
        (e) =>
            MapEntry(e.key.toString(), _resolveJsonLike(e.value, resolveValue)),
      ),
    );
  }
  return value;
}

// ─── Main executor ───────────────────────────────────────────────────────────

/// Handles [BotCreatorActionType.httpRequest].
///
/// Returns `true` when the action was handled, `false` otherwise.
///
/// The [setGlobalVariable] callback is used to persist results to global
/// variables, decoupling this executor from any concrete store implementation.
///
/// Note: `saveJsonPathToGlobalVar` has been intentionally removed — the
/// extracted value is exposed as a runtime variable (`{{resultKey.jsonPath}}`)
/// which is sufficient for the vast majority of use cases.
Future<bool> executeHttpAction({
  required BotCreatorActionType type,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
  required void Function(String message)? onLog,
  required Future<void> Function(String key, String value) setGlobalVariable,
}) async {
  if (type != BotCreatorActionType.httpRequest) return false;

  final resolvedUrl = resolveValue((payload['url'] ?? '').toString()).trim();
  if (resolvedUrl.isEmpty) {
    throw Exception('url is required for httpRequest');
  }

  final method = _normalizeMethod(payload['method'], resolveValue);
  final bodyMode =
      resolveValue((payload['bodyMode'] ?? 'json').toString()).toLowerCase();

  final headersRaw = Map<String, dynamic>.from(
    (payload['headers'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
  final headers = <String, String>{};
  for (final entry in headersRaw.entries) {
    final key = resolveValue(entry.key).trim();
    if (key.isEmpty) continue;
    headers[key] = resolveValue(entry.value?.toString() ?? '');
  }

  Object? requestBody;
  if (_supportsBody(method)) {
    if (bodyMode == 'text') {
      requestBody = resolveValue((payload['bodyText'] ?? '').toString());
    } else {
      final bodyJsonRaw =
          (payload['bodyJson'] is Map)
              ? Map<String, dynamic>.from(
                (payload['bodyJson'] as Map).cast<String, dynamic>(),
              )
              : <String, dynamic>{};
      final resolvedJson = _resolveJsonLike(bodyJsonRaw, resolveValue);
      requestBody = jsonEncode(resolvedJson);
      headers.putIfAbsent('Content-Type', () => 'application/json');
    }
  }

  final uri = Uri.tryParse(resolvedUrl);
  if (uri == null) {
    throw Exception('Invalid URL for httpRequest: $resolvedUrl');
  }

  final request = http.Request(method, uri);
  request.headers.addAll(headers);
  if (requestBody != null && requestBody.toString().isNotEmpty) {
    request.body = requestBody.toString();
  }

  onLog?.call('HTTP: $method $resolvedUrl');
  if (request.body.isNotEmpty) {
    onLog?.call('HTTP Payload sent: ${request.body}');
  }

  final streamed = await http.Client().send(request);
  final responseBody = await streamed.stream.bytesToString();
  final status = streamed.statusCode;

  onLog?.call('HTTP Response: $status (${responseBody.length} bytes)');
  if (responseBody.isNotEmpty) {
    onLog?.call('HTTP Payload received: $responseBody');
  }

  results[resultKey] = 'HTTP $status';
  variables['http.status'] = '$status';
  variables['http.body'] = responseBody;
  variables['action.$resultKey.status'] = '$status';
  variables['action.$resultKey.body'] = responseBody;
  variables['$resultKey.status'] = '$status';
  variables['$resultKey.body'] = responseBody;

  final saveBodyTo =
      resolveValue((payload['saveBodyToGlobalVar'] ?? '').toString()).trim();
  if (saveBodyTo.isNotEmpty) {
    await setGlobalVariable(saveBodyTo, responseBody);
  }

  final saveStatusTo =
      resolveValue((payload['saveStatusToGlobalVar'] ?? '').toString()).trim();
  if (saveStatusTo.isNotEmpty) {
    await setGlobalVariable(saveStatusTo, '$status');
  }

  final extractPath =
      resolveValue((payload['extractJsonPath'] ?? '').toString()).trim();
  if (extractPath.isNotEmpty) {
    dynamic decoded;
    try {
      decoded = jsonDecode(responseBody);
    } catch (_) {
      decoded = null;
    }

    if (decoded != null) {
      final extracted = _extractByJsonPath(decoded, extractPath);
      if (extracted != null) {
        final extractedAsString =
            extracted is String
                ? extracted
                : (extracted is num || extracted is bool)
                ? extracted.toString()
                : jsonEncode(extracted);
        variables['http.jsonPath'] = extractedAsString;
        variables['action.$resultKey.jsonPath'] = extractedAsString;
        variables['$resultKey.jsonPath'] = extractedAsString;
        // Note: saveJsonPathToGlobalVar removed — use {{resultKey.jsonPath}}
      }
    }
  }

  return true;
}
