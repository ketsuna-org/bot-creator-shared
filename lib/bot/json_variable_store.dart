import 'dart:convert';

import 'variable_database.dart';
import '../utils/bdfd_duration_parser.dart';

/// In-memory implementation of [VariableDatabase] backed by Dart Maps.
/// No persistence — used for runtime or fallback storage.
/// Suitable for: CLI runner (ZIP config source), app fallback when SQLite unavailable.
class JsonVariableStore implements VariableDatabase {
  final Map<String, dynamic> _globalVariables = {};
  final Map<String, int> _globalExpirations = {};
  final Map<String, Map<String, Map<String, dynamic>>> _scopedVariables = {};
  final Map<String, Map<String, Map<String, int>>> _scopedExpirations = {};

  JsonVariableStore();

  /// Initialize from existing maps (e.g., from BotConfig or JSON file).
  JsonVariableStore.fromMaps({
    Map<String, dynamic>? globalVariables,
    Map<String, Map<String, Map<String, dynamic>>>? scopedVariables,
  }) {
    if (globalVariables != null) {
      _globalVariables.addAll(globalVariables);
    }
    if (scopedVariables != null) {
      for (final scope in scopedVariables.entries) {
        final byId = <String, Map<String, dynamic>>{};
        for (final id in scope.value.entries) {
          byId[id.key] = Map<String, dynamic>.from(id.value);
        }
        _scopedVariables[scope.key] = byId;
      }
    }
  }

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <String, dynamic>{};
    final expiredKeys = <String>[];

    for (final entry in _globalVariables.entries) {
      final expiresAt = _globalExpirations[entry.key];
      if (expiresAt != null && expiresAt < now) {
        expiredKeys.add(entry.key);
        continue;
      }
      result[entry.key] = entry.value;
    }

    for (final key in expiredKeys) {
      _globalVariables.remove(key);
      _globalExpirations.remove(key);
    }

    return result;
  }

  @override
  Future<dynamic> getGlobalVariable(String botId, String key) async {
    final expiresAt = _globalExpirations[key];
    if (expiresAt != null && expiresAt < DateTime.now().millisecondsSinceEpoch) {
      _globalVariables.remove(key);
      _globalExpirations.remove(key);
      return null;
    }
    return _globalVariables[key];
  }

  @override
  Future<void> setGlobalVariable(
    String botId,
    String key,
    dynamic value, {
    String? ttl,
  }) async {
    _globalVariables[key] = _normalizeVariableValue(value);
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = _parseTtl(ttl, now);
    if (expiresAt != null) {
      _globalExpirations[key] = expiresAt;
    } else {
      _globalExpirations.remove(key);
    }
  }

  @override
  Future<void> renameGlobalVariable(
    String botId,
    String oldKey,
    String newKey,
  ) async {
    if (!_globalVariables.containsKey(oldKey)) {
      return;
    }
    final value = _globalVariables.remove(oldKey);
    _globalVariables[newKey] = value;

    final expiration = _globalExpirations.remove(oldKey);
    if (expiration != null) {
      _globalExpirations[newKey] = expiration;
    }
  }

  @override
  Future<void> removeGlobalVariable(String botId, String key) async {
    _globalVariables.remove(key);
    _globalExpirations.remove(key);
  }

  @override
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
  ) async {
    final byScope = _scopedVariables[scope] ?? {};
    final values = byScope[contextId] ?? {};
    final expirations = _scopedExpirations[scope]?[contextId] ?? {};
    final now = DateTime.now().millisecondsSinceEpoch;

    final result = <String, dynamic>{};
    final expiredKeys = <String>[];

    for (final entry in values.entries) {
      final expiresAt = expirations[entry.key];
      if (expiresAt != null && expiresAt < now) {
        expiredKeys.add(entry.key);
        continue;
      }
      result[entry.key] = entry.value;
    }

    if (expiredKeys.isNotEmpty) {
      for (final key in expiredKeys) {
        removeScopedVariable(botId, scope, contextId, key);
        _scopedExpirations[scope]?[contextId]?.remove(key);
      }
    }

    return result;
  }

  @override
  Future<dynamic> getScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    final byScope = _scopedExpirations[scope];
    final byId = byScope?[contextId];
    final expiresAt = byId?[key];
    if (expiresAt != null && expiresAt < DateTime.now().millisecondsSinceEpoch) {
      removeScopedVariable(botId, scope, contextId, key);
      return null;
    }

    final values = await getScopedVariables(botId, scope, contextId);
    return values[key];
  }

  @override
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic value, {
    String? ttl,
  }) async {
    final byScope = _scopedVariables.putIfAbsent(
      scope,
      () => <String, Map<String, dynamic>>{},
    );
    final byId = byScope.putIfAbsent(contextId, () => <String, dynamic>{});
    byId[key] = _normalizeVariableValue(value);

    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = _parseTtl(ttl, now);
    if (expiresAt != null) {
      final expByScope = _scopedExpirations.putIfAbsent(
        scope,
        () => <String, Map<String, int>>{},
      );
      final expById = expByScope.putIfAbsent(contextId, () => <String, int>{});
      expById[key] = expiresAt;
    } else {
      _scopedExpirations[scope]?[contextId]?.remove(key);
    }
  }

  int? _parseTtl(String? ttl, int now) {
    if (ttl == null || ttl.trim().isEmpty) return null;
    final duration = parseBdfdDuration(ttl);
    if (duration == null) return null;
    return now + duration.inMilliseconds;
  }

  @override
  Future<int?> getScopedVariableTtl(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    final byScope = _scopedExpirations[scope];
    final byId = byScope?[contextId];
    final expiresAt = byId?[key];
    if (expiresAt == null) return null;

    final remaining = expiresAt - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? remaining : 0;
  }

  @override
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  ) async {
    final byScope = _scopedVariables[scope];
    final byId = byScope?[contextId];
    if (byId == null || !byId.containsKey(oldKey)) {
      return;
    }
    final value = byId.remove(oldKey);
    byId[newKey] = value;

    final expiration = _scopedExpirations[scope]?[contextId]?.remove(oldKey);
    if (expiration != null) {
      final expByScope = _scopedExpirations.putIfAbsent(
        scope,
        () => <String, Map<String, int>>{},
      );
      final expById = expByScope.putIfAbsent(contextId, () => <String, int>{});
      expById[newKey] = expiration;
    }
  }

  @override
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    final byScope = _scopedVariables[scope];
    final byId = byScope?[contextId];
    if (byId == null) {
      return;
    }
    byId.remove(key);
    _scopedExpirations[scope]?[contextId]?.remove(key);
  }

  @override
  Future<List<String>> listContextIds(
    String botId,
    String scope, {
    String? searchKey,
  }) async {
    final byScope = _scopedVariables[scope];
    if (byScope == null) return [];

    final contextIds =
        byScope.entries
            .where((entry) {
              if (searchKey == null) return true;
              // Check if any key in this context starts with searchKey
              return entry.value.keys.any((k) => k.startsWith(searchKey));
            })
            .map((e) => e.key)
            .toList();

    return contextIds;
  }

  @override
  Future<Map<String, dynamic>> queryScopedVariableIndex(
    String botId,
    String scope,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
  }) async {
    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit.clamp(1, 25);
    final byScope =
        _scopedVariables[scope] ?? const <String, Map<String, dynamic>>{};

    final items = <Map<String, dynamic>>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    final expByScope = _scopedExpirations[scope] ?? {};

    for (final entry in byScope.entries) {
      if (!entry.value.containsKey(key)) {
        continue;
      }

      final expiresAt = expByScope[entry.key]?[key];
      if (expiresAt != null && expiresAt < now) {
        continue;
      }

      items.add(<String, dynamic>{
        'contextId': entry.key,
        'key': key,
        'value': entry.value[key],
      });
    }

    items.sort(
      (a, b) => _compareVariableValues(a['value'], b['value'], descending),
    );

    final total = items.length;
    final end =
        (safeOffset + safeLimit) > total ? total : (safeOffset + safeLimit);
    final paged =
        safeOffset >= total
            ? const <Map<String, dynamic>>[]
            : items.sublist(safeOffset, end);

    return <String, dynamic>{
      'items': paged,
      'count': paged.length,
      'total': total,
    };
  }

  @override
  Future<void> deleteAllForBot(String botId) async {
    _globalVariables.clear();
    _scopedVariables.clear();
  }

  /// Normalize variable value: preserve numbers, coerce others to strings.
  static dynamic _normalizeVariableValue(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is List) {
      return value.map(_normalizeVariableValue).toList(growable: false);
    }
    if (value is Map) {
      return value.map(
        (key, value) =>
            MapEntry(key.toString(), _normalizeVariableValue(value)),
      );
    }
    return value.toString();
  }

  @override
  Future<void> pushScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic element,
  ) async {
    final current = await getScopedVariable(botId, scope, contextId, key);
    final list = _toList(current) ?? [];
    list.add(element);
    await setScopedVariable(botId, scope, contextId, key, list);
  }

  @override
  Future<dynamic> popScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    final current = await getScopedVariable(botId, scope, contextId, key);
    final list = _toList(current);
    if (list == null || list.isEmpty) {
      return null;
    }
    final popped = list.removeLast();
    await setScopedVariable(botId, scope, contextId, key, list);
    return popped;
  }

  @override
  Future<dynamic> removeScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    final current = await getScopedVariable(botId, scope, contextId, key);
    final list = _toList(current);
    if (list == null || index < 0 || index >= list.length) {
      return null;
    }
    final removed = list.removeAt(index);
    await setScopedVariable(botId, scope, contextId, key, list);
    return removed;
  }

  @override
  Future<dynamic> getScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    final current = await getScopedVariable(botId, scope, contextId, key);
    final list = _toList(current);
    if (list == null || index < 0 || index >= list.length) {
      return null;
    }
    return list[index];
  }

  @override
  Future<int> getScopedArrayLength(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    final current = await getScopedVariable(botId, scope, contextId, key);
    final list = _toList(current);
    return list?.length ?? 0;
  }

  @override
  Future<Map<String, dynamic>> queryScopedArray(
    String botId,
    String scope,
    String contextId,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
    String? filter,
  }) async {
    final current = await getScopedVariable(botId, scope, contextId, key);
    final list = _toList(current) ?? [];

    // Apply filter
    List<dynamic> filtered = list;
    if (filter != null && filter.trim().isNotEmpty) {
      filtered = _applyArrayFilter(list, filter.trim());
    }

    // Sort
    filtered.sort((a, b) => _compareVariableValues(a, b, descending));

    // Paginate
    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit < 1 ? 1 : (limit > 25 ? 25 : limit);
    final start = safeOffset;
    final end = (safeOffset + safeLimit).clamp(0, filtered.length);
    final items = filtered.sublist(start, end);

    return {'items': items, 'count': items.length, 'total': filtered.length};
  }

  List<dynamic> _applyArrayFilter(List<dynamic> list, String filter) {
    if (filter.isEmpty) return list;

    final result = <dynamic>[];
    for (final item in list) {
      if (_matchesArrayFilter(item, filter)) {
        result.add(item);
      }
    }
    return result;
  }

  bool _matchesArrayFilter(dynamic item, String filter) {
    if (filter.startsWith('> ')) {
      final value = num.tryParse(filter.substring(2));
      if (value == null || item is! num) return false;
      return item > value;
    }
    if (filter.startsWith('< ')) {
      final value = num.tryParse(filter.substring(2));
      if (value == null || item is! num) return false;
      return item < value;
    }
    if (filter.startsWith('>= ')) {
      final value = num.tryParse(filter.substring(3));
      if (value == null || item is! num) return false;
      return item >= value;
    }
    if (filter.startsWith('<= ')) {
      final value = num.tryParse(filter.substring(3));
      if (value == null || item is! num) return false;
      return item <= value;
    }
    if (filter.startsWith('== ')) {
      final valueStr = filter.substring(3);
      if (item is String) return item == valueStr;
      final value = num.tryParse(valueStr);
      if (value == null) return false;
      return item == value;
    }
    if (filter.startsWith('contains ')) {
      final search = filter.substring(9);
      return item.toString().toLowerCase().contains(search.toLowerCase());
    }
    return false;
  }

  List<dynamic>? _toList(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    return null;
  }

  /// Export current state as maps (for JSON serialization, backup, etc).
  Map<String, dynamic> exportGlobalVariables() =>
      Map<String, dynamic>.from(_globalVariables);

  Map<String, Map<String, Map<String, dynamic>>> exportScopedVariables() {
    final export = <String, Map<String, Map<String, dynamic>>>{};
    for (final scope in _scopedVariables.entries) {
      final byId = <String, Map<String, dynamic>>{};
      for (final id in scope.value.entries) {
        byId[id.key] = Map<String, dynamic>.from(id.value);
      }
      export[scope.key] = byId;
    }
    return export;
  }

  static int _compareVariableValues(
    dynamic left,
    dynamic right,
    bool descending,
  ) {
    final normalized = _compareNormalized(left, right);
    return descending ? -normalized : normalized;
  }

  static int _compareNormalized(dynamic left, dynamic right) {
    if (left is num && right is num) {
      return left.compareTo(right);
    }
    if (left is bool && right is bool) {
      return (left ? 1 : 0).compareTo(right ? 1 : 0);
    }
    final leftText = _valueToComparableString(left);
    final rightText = _valueToComparableString(right);
    return leftText.compareTo(rightText);
  }

  static String _valueToComparableString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.toLowerCase();
    if (value is List || value is Map) return jsonEncode(value).toLowerCase();
    return value.toString().toLowerCase();
  }
}
