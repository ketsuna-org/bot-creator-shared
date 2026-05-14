import 'dart:convert';

import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:nyxx/nyxx.dart';

List<EmbedFieldBuilder> buildResolvedEmbedFields({
  required Map<String, dynamic> embedJson,
  required String Function(String) resolve,
  int maxFields = 25,
}) {
  final fields = <EmbedFieldBuilder>[];

  void addField(dynamic rawField) {
    if (fields.length >= maxFields || rawField is! Map) {
      return;
    }

    final field = Map<String, dynamic>.from(
      rawField.map((key, value) => MapEntry(key.toString(), value)),
    );
    final name = resolve((field['name'] ?? '').toString()).trim();
    final value = resolve((field['value'] ?? '').toString()).trim();
    if (name.isEmpty || value.isEmpty) {
      return;
    }

    fields.add(
      EmbedFieldBuilder(
        name: name,
        value: value,
        isInline: field['inline'] == true,
      ),
    );
  }

  final staticFields =
      (embedJson['fields'] as List?)?.whereType<Map>() ?? const [];
  for (final rawField in staticFields) {
    addField(rawField);
  }

  if (fields.length >= maxFields) {
    return fields;
  }

  final fieldsTemplate = (embedJson['fieldsTemplate'] ?? '').toString().trim();
  if (fieldsTemplate.isEmpty) {
    return fields;
  }

  try {
    final resolved = resolve(fieldsTemplate).trim();
    if (resolved.isEmpty) {
      return fields;
    }

    final decoded = decodeJsonStringIfNeeded(resolved);
    dynamic dynamicFields = decoded;
    if (dynamicFields is String) {
      dynamicFields = jsonDecode(dynamicFields);
    }
    if (dynamicFields is! List) {
      return fields;
    }

    for (final rawField in dynamicFields) {
      addField(rawField);
    }
  } catch (_) {
    // Ignore malformed dynamic field payloads to avoid breaking the whole embed.
  }

  return fields;
}
