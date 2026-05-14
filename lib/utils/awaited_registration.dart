import 'dart:convert';

Object? _canonicalizeAwaitedValue(Object? value) {
  if (value is Map) {
    final entries = <String, Object?>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
    final sortedKeys = entries.keys.toList(growable: false)..sort();
    return <String, Object?>{
      for (final key in sortedKeys)
        key: _canonicalizeAwaitedValue(entries[key]),
    };
  }

  if (value is List) {
    return value
        .map<Object?>((item) => _canonicalizeAwaitedValue(item))
        .toList(growable: false);
  }

  if (value is num || value is bool || value == null || value is String) {
    return value;
  }

  return value.toString();
}

Object? _decodeAwaitedRegistration(Object? raw) {
  if (raw is Map || raw is List) {
    return _canonicalizeAwaitedValue(raw);
  }

  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) {
    return text;
  }

  try {
    return _canonicalizeAwaitedValue(jsonDecode(text));
  } catch (_) {
    return text;
  }
}

String awaitedRegistrationSnapshot(Object? raw) {
  return jsonEncode(_decodeAwaitedRegistration(raw));
}
