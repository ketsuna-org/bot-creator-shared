part of '../bdfd_ast_transpiler.dart';

extension _BdfdAstTranspilationScopeRuntimeBuilders
    on _BdfdAstTranspilationScope {
  Action? _buildStartThreadAction(BdfdFunctionCallAst node) {
    final name = _stringifyArgument(node, 0).trim();
    final channelId = _stringifyArgument(node, 1).trim();
    final messageId = _stringifyArgument(node, 2).trim();
    final archiveDurationRaw = _stringifyArgument(node, 3).trim();
    final archiveDuration = _normalizeThreadArchiveDuration(archiveDurationRaw);

    if (name.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a thread name.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    return Action(
      type: BotCreatorActionType.createThread,
      key: '_bdfd_thread_${_threadActionCounter++}',
      payload: <String, dynamic>{
        'name': name,
        'channelId': channelId,
        'messageId': messageId,
        'autoArchiveDuration': archiveDuration.toString(),
        'type': 'public',
      },
    );
  }

  Action? _buildEditThreadAction(BdfdFunctionCallAst node) {
    final threadId = _stringifyArgument(node, 0).trim();
    if (threadId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a thread ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final name = _normalizeThreadOptional(_stringifyArgument(node, 1));
    final archived = _normalizeThreadOptionalBool(_stringifyArgument(node, 2));
    final archiveDurationRaw = _normalizeThreadOptional(
      _stringifyArgument(node, 3),
    );
    final locked = _normalizeThreadOptionalBool(_stringifyArgument(node, 4));
    final slowmode = _normalizeThreadOptional(_stringifyArgument(node, 5));

    return Action(
      type: BotCreatorActionType.updateChannel,
      payload: <String, dynamic>{
        'channelId': threadId,
        if (name != null) 'name': name,
        if (archived != null) 'archived': archived,
        if (archiveDurationRaw != null)
          'autoArchiveDuration':
              _normalizeThreadArchiveDuration(archiveDurationRaw).toString(),
        if (locked != null) 'locked': locked,
        if (slowmode != null) 'slowmode': slowmode,
      },
    );
  }

  Action? _buildThreadMemberAction(
    BdfdFunctionCallAst node, {
    required bool add,
  }) {
    final threadId = _stringifyArgument(node, 0).trim();
    final userId = _stringifyArgument(node, 1).trim();
    if (threadId.isEmpty || userId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires both thread ID and user ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    return Action(
      type:
          add
              ? BotCreatorActionType.addThreadMember
              : BotCreatorActionType.removeThreadMember,
      payload: <String, dynamic>{'threadId': threadId, 'userId': userId},
    );
  }

  int _normalizeThreadArchiveDuration(String raw) {
    const allowed = <int>[60, 1440, 4320, 10080];
    final parsed = int.tryParse(raw.trim()) ?? 60;
    return allowed.reduce(
      (prev, curr) =>
          (curr - parsed).abs() < (prev - parsed).abs() ? curr : prev,
    );
  }

  bool _shouldReturnStartThreadId(BdfdFunctionCallAst node) {
    final raw = _stringifyArgument(node, 4).trim().toLowerCase();
    return raw == 'true' || raw == 'yes' || raw == '1' || raw == 'on';
  }

  String? _normalizeThreadOptional(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == '!unchanged') {
      return null;
    }
    return trimmed;
  }

  bool? _normalizeThreadOptionalBool(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty || normalized == '!unchanged') {
      return null;
    }
    if (normalized == 'true' ||
        normalized == 'yes' ||
        normalized == '1' ||
        normalized == 'on') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == 'no' ||
        normalized == '0' ||
        normalized == 'off') {
      return false;
    }
    return null;
  }

  void _jsonParse(BdfdFunctionCallAst node) {
    final raw = _stringifyArgument(node, 0).trim();
    if (raw.isEmpty) {
      _hasJsonContext = false;
      _jsonContext = null;
      _lastDeferredJsonResultKeyPrefix = null;
      return;
    }

    // If the argument contains runtime placeholders, we cannot decode it at
    // compile-time.  Switch to deferred mode so that all subsequent JSON
    // operations are collected and emitted as a single runtimeJsonBlock action.
    if (raw.contains('((')) {
      _deferredJsonMode = true;
      _deferredJsonSource = raw;
      _deferredJsonOps.clear();
      _deferredJsonReadCounter = 0;
      _deferredJsonResultKeyPrefix = 'rtJson_${_deferredJsonBlockCounter++}';
      _hasJsonContext = false;
      _jsonContext = null;
      _lastDeferredJsonResultKeyPrefix = null;
      return;
    }

    try {
      _jsonContext = jsonDecode(raw);
      _hasJsonContext = true;
      _lastDeferredJsonResultKeyPrefix = null;
    } catch (_) {
      _hasJsonContext = false;
      _jsonContext = null;
      _lastDeferredJsonResultKeyPrefix = null;
    }
  }

  bool _resumeDeferredJsonFromLastRuntimeContext() {
    if (_deferredJsonMode || _hasJsonContext) {
      return _deferredJsonMode;
    }

    final previousKey = _lastDeferredJsonResultKeyPrefix;
    if (previousKey == null || previousKey.isEmpty) {
      return false;
    }

    _deferredJsonMode = true;
    _deferredJsonSource = '(($previousKey))';
    _deferredJsonOps.clear();
    _deferredJsonReadCounter = 0;
    _deferredJsonResultKeyPrefix = 'rtJson_${_deferredJsonBlockCounter++}';
    return true;
  }

  String _jsonGet(BdfdFunctionCallAst node) {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final segments = _jsonPathSegmentsRaw(node);
      final readIndex = _deferredJsonReadCounter++;
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'get',
        'path': segments,
        'readIndex': readIndex,
      });
      return '(($_deferredJsonResultKeyPrefix.json_$readIndex))';
    }
    if (!_hasJsonContext) {
      return '';
    }
    final segments = _jsonPathSegments(node);
    final value = _jsonGetPathValue(segments);
    return _jsonStringifyValue(value);
  }

  void _jsonSet(BdfdFunctionCallAst node, {required bool forceString}) {
    final pathLength = node.arguments.length - 1;
    if (pathLength < 1) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one key and one value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return;
    }

    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final segments = _jsonPathSegmentsRaw(node, endExclusive: pathLength);
      final rawValue = _stringifyArgument(node, pathLength);
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'set',
        'path': segments,
        'value': rawValue,
        'forceString': forceString,
      });
      return;
    }

    final pathSegments = _jsonPathSegments(node, endExclusive: pathLength);
    final rawValue = _stringifyArgument(node, pathLength);
    final value = forceString ? rawValue : _coerceJsonValue(rawValue);
    _jsonSetPathValue(pathSegments, value);
  }

  void _jsonUnset(BdfdFunctionCallAst node) {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final segments = _jsonPathSegmentsRaw(node);
      _deferredJsonOps.add(<String, dynamic>{
        'op': segments.isEmpty ? 'clear' : 'unset',
        'path': segments,
      });
      return;
    }
    if (!_hasJsonContext) {
      return;
    }
    final segments = _jsonPathSegments(node);
    if (segments.isEmpty) {
      _jsonClear();
      return;
    }
    _jsonRemovePathValue(segments);
  }

  void _jsonClear() {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      _deferredJsonOps.add(<String, dynamic>{'op': 'clear'});
      return;
    }
    _jsonContext = null;
    _hasJsonContext = false;
    _lastDeferredJsonResultKeyPrefix = null;
  }

  String _jsonExists(BdfdFunctionCallAst node) {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final segments = _jsonPathSegmentsRaw(node);
      final readIndex = _deferredJsonReadCounter++;
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'exists',
        'path': segments,
        'readIndex': readIndex,
      });
      return '(($_deferredJsonResultKeyPrefix.json_$readIndex))';
    }
    if (!_hasJsonContext) {
      return 'false';
    }
    final segments = _jsonPathSegments(node);
    final exists = _jsonPathExists(segments);
    return exists ? 'true' : 'false';
  }

  String _jsonStringify() {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      // In deferred mode, the runtime block always stores the full JSON
      // payload under its action key (e.g. rtJson_0). Returning the root key
      // avoids fragile json_n indirection when setServerVar consumes
      // $jsonStringify.
      return '(($_deferredJsonResultKeyPrefix))';
    }
    if (!_hasJsonContext) {
      return '';
    }
    return jsonEncode(_jsonContext);
  }

  String _jsonPretty(BdfdFunctionCallAst node) {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final indentRaw = _stringifyArgument(node, 0).trim();
      final readIndex = _deferredJsonReadCounter++;
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'pretty',
        'indent': indentRaw,
        'readIndex': readIndex,
      });
      return '(($_deferredJsonResultKeyPrefix.json_$readIndex))';
    }
    if (!_hasJsonContext) {
      return '';
    }
    final indentRaw = _stringifyArgument(node, 0).trim();
    final indent = int.tryParse(indentRaw);
    final spaces = (indent == null || indent < 0) ? 2 : indent;
    return JsonEncoder.withIndent(' ' * spaces).convert(_jsonContext);
  }

  void _jsonArray(BdfdFunctionCallAst node) {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final segments = _jsonPathSegmentsRaw(node);
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'initArray',
        'path': segments,
      });
      return;
    }
    final segments = _jsonPathSegments(node);
    _jsonSetPathValue(segments, <dynamic>[]);
  }

  String _jsonArrayCount(BdfdFunctionCallAst node) {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final segments = _jsonPathSegmentsRaw(node);
      final readIndex = _deferredJsonReadCounter++;
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'arrayCount',
        'path': segments,
        'readIndex': readIndex,
      });
      return '(($_deferredJsonResultKeyPrefix.json_$readIndex))';
    }
    if (!_hasJsonContext) {
      return '';
    }
    final value = _jsonGetPathValue(_jsonPathSegments(node));
    if (value is List) {
      return value.length.toString();
    }
    return '0';
  }

  String _jsonArrayIndex(BdfdFunctionCallAst node) {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      if (node.arguments.length < 2) return '-1';
      final segments = _jsonPathSegmentsRaw(
        node,
        endExclusive: node.arguments.length - 1,
      );
      final expected = _stringifyArgument(node, node.arguments.length - 1);
      final readIndex = _deferredJsonReadCounter++;
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'arrayIndex',
        'path': segments,
        'value': expected,
        'readIndex': readIndex,
      });
      return '(($_deferredJsonResultKeyPrefix.json_$readIndex))';
    }
    if (!_hasJsonContext) {
      return '';
    }
    if (node.arguments.length < 2) {
      return '-1';
    }

    final path = _jsonPathSegments(
      node,
      endExclusive: node.arguments.length - 1,
    );
    final list = _jsonGetPathValue(path);
    if (list is! List) {
      return '-1';
    }

    final expected = _coerceJsonPrimitive(
      _stringifyArgument(node, node.arguments.length - 1),
    );
    final index = list.indexWhere((item) => item == expected);
    return index.toString();
  }

  void _jsonArrayAppend(BdfdFunctionCallAst node) {
    if (node.arguments.length < 2) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a key path and a value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return;
    }

    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final segments = _jsonPathSegmentsRaw(
        node,
        endExclusive: node.arguments.length - 1,
      );
      final rawValue = _stringifyArgument(node, node.arguments.length - 1);
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'arrayAppend',
        'path': segments,
        'value': rawValue,
      });
      return;
    }

    final path = _jsonPathSegments(
      node,
      endExclusive: node.arguments.length - 1,
    );
    final rawValue = _stringifyArgument(node, node.arguments.length - 1);
    final value = _coerceJsonValue(rawValue);
    final list = _jsonEnsureArray(path);
    list.add(value);
  }

  String _jsonArrayPop(BdfdFunctionCallAst node) {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final segments = _jsonPathSegmentsRaw(node);
      final readIndex = _deferredJsonReadCounter++;
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'arrayPop',
        'path': segments,
        'readIndex': readIndex,
      });
      return '(($_deferredJsonResultKeyPrefix.json_$readIndex))';
    }
    final list = _jsonEnsureArray(_jsonPathSegments(node));
    if (list.isEmpty) {
      return '';
    }
    final removed = list.removeLast();
    return _jsonStringifyValue(removed);
  }

  String _jsonArrayShift(BdfdFunctionCallAst node) {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final segments = _jsonPathSegmentsRaw(node);
      final readIndex = _deferredJsonReadCounter++;
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'arrayShift',
        'path': segments,
        'readIndex': readIndex,
      });
      return '(($_deferredJsonResultKeyPrefix.json_$readIndex))';
    }
    final list = _jsonEnsureArray(_jsonPathSegments(node));
    if (list.isEmpty) {
      return '';
    }
    final removed = list.removeAt(0);
    return _jsonStringifyValue(removed);
  }

  void _jsonArrayUnshift(BdfdFunctionCallAst node) {
    if (node.arguments.length < 2) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a key path and a value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return;
    }

    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final segments = _jsonPathSegmentsRaw(
        node,
        endExclusive: node.arguments.length - 1,
      );
      final rawValue = _stringifyArgument(node, node.arguments.length - 1);
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'arrayUnshift',
        'path': segments,
        'value': rawValue,
      });
      return;
    }

    final path = _jsonPathSegments(
      node,
      endExclusive: node.arguments.length - 1,
    );
    final value = _coerceJsonPrimitive(
      _stringifyArgument(node, node.arguments.length - 1),
    );
    final list = _jsonEnsureArray(path);
    list.insert(0, value);
  }

  void _jsonArraySort(BdfdFunctionCallAst node) {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final segments = _jsonPathSegmentsRaw(node);
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'arraySort',
        'path': segments,
      });
      return;
    }
    final list = _jsonEnsureArray(_jsonPathSegments(node));
    list.sort((left, right) {
      final leftNumber = left is num ? left : num.tryParse(left.toString());
      final rightNumber = right is num ? right : num.tryParse(right.toString());
      if (leftNumber != null && rightNumber != null) {
        return leftNumber.compareTo(rightNumber);
      }
      if (leftNumber != null) {
        return -1;
      }
      if (rightNumber != null) {
        return 1;
      }
      return left.toString().compareTo(right.toString());
    });
  }

  void _jsonArrayReverse(BdfdFunctionCallAst node) {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final segments = _jsonPathSegmentsRaw(node);
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'arrayReverse',
        'path': segments,
      });
      return;
    }
    final list = _jsonEnsureArray(_jsonPathSegments(node));
    final reversed = list.reversed.toList(growable: false);
    list
      ..clear()
      ..addAll(reversed);
  }

  String _jsonJoinArray(BdfdFunctionCallAst node) {
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      if (node.arguments.isEmpty) return '';
      final separator = _stringifyArgument(node, node.arguments.length - 1);
      final segments = _jsonPathSegmentsRaw(
        node,
        endExclusive: node.arguments.length - 1,
      );
      final readIndex = _deferredJsonReadCounter++;
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'joinArray',
        'path': segments,
        'separator': separator,
        'readIndex': readIndex,
      });
      return '(($_deferredJsonResultKeyPrefix.json_$readIndex))';
    }
    if (!_hasJsonContext) {
      return '';
    }
    if (node.arguments.isEmpty) {
      return '';
    }

    final separator = _stringifyArgument(node, node.arguments.length - 1);
    final path = _jsonPathSegments(
      node,
      endExclusive: node.arguments.length - 1,
    );
    final value = _jsonGetPathValue(path);
    if (value is! List) {
      return '';
    }
    return value.map(_jsonStringifyValue).join(separator);
  }

  String _jsonKeys(BdfdFunctionCallAst node) {
    final hasSeparatorArg = node.arguments.length >= 2;
    if (_deferredJsonMode || _resumeDeferredJsonFromLastRuntimeContext()) {
      final separator =
          hasSeparatorArg
              ? _stringifyArgument(node, node.arguments.length - 1)
              : ',';
      final segments = _jsonPathSegmentsRaw(
        node,
        endExclusive: hasSeparatorArg ? node.arguments.length - 1 : null,
      );
      final readIndex = _deferredJsonReadCounter++;
      _deferredJsonOps.add(<String, dynamic>{
        'op': 'keys',
        'path': segments,
        'separator': separator,
        'readIndex': readIndex,
      });
      return '(($_deferredJsonResultKeyPrefix.json_$readIndex))';
    }
    if (!_hasJsonContext) {
      return '';
    }

    final separator =
        hasSeparatorArg
            ? _stringifyArgument(node, node.arguments.length - 1)
            : ',';
    final path = _jsonPathSegments(
      node,
      endExclusive: hasSeparatorArg ? node.arguments.length - 1 : null,
    );
    final value = path.isEmpty ? _jsonContext : _jsonGetPathValue(path);
    if (value is! Map) {
      return '';
    }
    return value.keys.map((k) => k.toString()).join(separator);
  }

  List<dynamic> _jsonEnsureArray(List<Object> path) {
    final existing = _jsonGetPathValue(path);
    if (existing is List<dynamic>) {
      return existing;
    }
    _jsonSetPathValue(path, <dynamic>[]);
    final resolved = _jsonGetPathValue(path);
    if (resolved is List<dynamic>) {
      return resolved;
    }
    return <dynamic>[];
  }

  List<Object> _jsonPathSegments(
    BdfdFunctionCallAst node, {
    int startInclusive = 0,
    int? endExclusive,
  }) {
    final end = endExclusive ?? node.arguments.length;
    final segments = <Object>[];
    for (var index = startInclusive; index < end; index++) {
      final raw = _stringifyArgument(node, index).trim();
      if (raw.isEmpty) {
        continue;
      }
      final numeric = int.tryParse(raw);
      if (numeric != null) {
        segments.add(numeric);
      } else {
        segments.add(raw);
      }
    }
    return segments;
  }

  /// Like [_jsonPathSegments] but keeps segments as raw strings (including
  /// potential runtime placeholders) for deferred operations.
  List<String> _jsonPathSegmentsRaw(
    BdfdFunctionCallAst node, {
    int startInclusive = 0,
    int? endExclusive,
  }) {
    final end = endExclusive ?? node.arguments.length;
    final segments = <String>[];
    for (var index = startInclusive; index < end; index++) {
      final raw = _stringifyArgument(node, index).trim();
      if (raw.isNotEmpty) {
        segments.add(raw);
      }
    }
    return segments;
  }

  /// Tries to decode [raw] as a JSON object/array first, falls back to
  /// [_coerceJsonPrimitive] for simple values.
  dynamic _coerceJsonValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return jsonDecode(trimmed);
      } catch (_) {
        // Not valid JSON — fall through to primitive coercion.
      }
    }
    return _coerceJsonPrimitive(raw);
  }

  /// Flushes any pending deferred JSON operations into a
  /// [BotCreatorActionType.runtimeJsonBlock] action and resets the state.
  Action? _flushDeferredJson() {
    if (!_deferredJsonMode) return null;
    final action = Action(
      type: BotCreatorActionType.runtimeJsonBlock,
      key: _deferredJsonResultKeyPrefix,
      payload: <String, dynamic>{
        'source': _deferredJsonSource,
        'operations': List<Map<String, dynamic>>.from(_deferredJsonOps),
      },
    );
    _lastDeferredJsonResultKeyPrefix = action.key;
    _deferredJsonMode = false;
    _deferredJsonSource = '';
    _deferredJsonOps.clear();
    _deferredJsonReadCounter = 0;
    _deferredJsonResultKeyPrefix = null;
    return action;
  }

  dynamic _coerceJsonPrimitive(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.toLowerCase() == 'true') {
      return true;
    }
    if (trimmed.toLowerCase() == 'false') {
      return false;
    }
    if (trimmed.toLowerCase() == 'null') {
      return null;
    }
    final asInt = int.tryParse(trimmed);
    if (asInt != null) {
      return asInt;
    }
    final asDouble = double.tryParse(trimmed);
    if (asDouble != null) {
      return asDouble;
    }
    return raw;
  }

  String _jsonStringifyValue(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return jsonEncode(value);
  }

  bool _jsonPathExists(List<Object> path) {
    if (!_hasJsonContext) {
      return false;
    }
    if (path.isEmpty) {
      return true;
    }

    dynamic current = _jsonContext;
    for (final segment in path) {
      if (segment is String) {
        if (current is! Map || !current.containsKey(segment)) {
          return false;
        }
        current = current[segment];
        continue;
      }
      if (segment is int) {
        if (current is! List || segment < 0 || segment >= current.length) {
          return false;
        }
        current = current[segment];
      }
    }
    return true;
  }

  dynamic _jsonGetPathValue(List<Object> path) {
    if (!_hasJsonContext) {
      return null;
    }
    dynamic current = _jsonContext;
    for (final segment in path) {
      if (segment is String) {
        if (current is! Map || !current.containsKey(segment)) {
          return null;
        }
        current = current[segment];
        continue;
      }
      if (segment is int) {
        if (current is! List || segment < 0 || segment >= current.length) {
          return null;
        }
        current = current[segment];
      }
    }
    return current;
  }

  void _jsonSetPathValue(List<Object> path, dynamic value) {
    if (path.isEmpty) {
      _jsonContext = value;
      _hasJsonContext = true;
      return;
    }

    if (!_hasJsonContext || _jsonContext == null) {
      _jsonContext = path.first is int ? <dynamic>[] : <String, dynamic>{};
      _hasJsonContext = true;
    }

    dynamic current = _jsonContext;
    for (var index = 0; index < path.length - 1; index++) {
      final segment = path[index];
      final next = path[index + 1];
      if (segment is String) {
        if (current is! Map) {
          return;
        }
        final existing = current[segment];
        if (existing == null) {
          current[segment] = next is int ? <dynamic>[] : <String, dynamic>{};
        }
        current = current[segment];
        continue;
      }

      if (segment is int) {
        if (current is! List || segment < 0) {
          return;
        }
        while (current.length <= segment) {
          current.add(null);
        }
        if (current[segment] == null) {
          current[segment] = next is int ? <dynamic>[] : <String, dynamic>{};
        }
        current = current[segment];
      }
    }

    final last = path.last;
    if (last is String) {
      if (current is Map) {
        current[last] = value;
      }
      return;
    }
    if (last is int) {
      if (current is! List || last < 0) {
        return;
      }
      while (current.length <= last) {
        current.add(null);
      }
      current[last] = value;
    }
  }

  void _jsonRemovePathValue(List<Object> path) {
    if (!_hasJsonContext) {
      return;
    }
    if (path.isEmpty) {
      _jsonClear();
      return;
    }

    dynamic current = _jsonContext;
    for (var index = 0; index < path.length - 1; index++) {
      final segment = path[index];
      if (segment is String) {
        if (current is! Map || !current.containsKey(segment)) {
          return;
        }
        current = current[segment];
        continue;
      }
      if (segment is int) {
        if (current is! List || segment < 0 || segment >= current.length) {
          return;
        }
        current = current[segment];
      }
    }

    final last = path.last;
    if (last is String) {
      if (current is Map) {
        current.remove(last);
      }
      return;
    }
    if (last is int) {
      if (current is List && last >= 0 && last < current.length) {
        current.removeAt(last);
      }
    }
  }

  void _storePendingHttpHeader(BdfdFunctionCallAst node) {
    final headerName = _stringifyArgument(node, 0).trim();
    final headerValue = _stringifyArgument(node, 1);
    if (headerName.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'HTTP header name cannot be empty.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return;
    }
    _pendingHttpHeaders[headerName] = headerValue;
  }

  Action _buildHttpRequestAction({
    required String method,
    required BdfdFunctionCallAst node,
  }) {
    final url = _stringifyArgument(node, 0).trim();
    if (url.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'HTTP request URL cannot be empty for ${node.name}.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
    }

    final key = '_bdfd_http_${_httpRequestCounter++}';
    _lastHttpRequestKey = key;
    final body = _stringifyArgument(node, 1);
    final headers = Map<String, dynamic>.from(_pendingHttpHeaders);
    _pendingHttpHeaders.clear();

    return Action(
      type: BotCreatorActionType.httpRequest,
      key: key,
      payload: <String, dynamic>{
        'url': url,
        'method': method,
        'bodyMode': 'text',
        'bodyText': body,
        'bodyJson': const <String, dynamic>{},
        'headers': headers,
        'saveBodyToGlobalVar': '',
        'saveStatusToGlobalVar': '',
        'extractJsonPath': '',
      },
    );
  }

  String? _latestHttpStatusPlaceholder(BdfdFunctionCallAst node) {
    if (_requireLatestHttpRequestKey(node) == null) {
      return null;
    }
    return '((http.status))';
  }

  String? _latestHttpResultPlaceholder(BdfdFunctionCallAst node) {
    if (_requireLatestHttpRequestKey(node) == null) {
      return null;
    }

    final jsonPath = _buildHttpResultJsonPath(node);
    if (jsonPath == null || jsonPath.isEmpty) {
      return '((http.body))';
    }
    return '((http.body.$jsonPath))';
  }

  String? _requireLatestHttpRequestKey(BdfdFunctionCallAst node) {
    final requestKey = _lastHttpRequestKey;
    if (requestKey != null && requestKey.isNotEmpty) {
      return requestKey;
    }
    _diagnostics.add(
      BdfdTranspileDiagnostic(
        message:
            '${node.name} requires a preceding HTTP request in the same BDFD script.',
        start: node.start,
        end: node.end,
        functionName: node.name,
      ),
    );
    return null;
  }

  String? _buildHttpResultJsonPath(BdfdFunctionCallAst node) {
    if (node.arguments.isEmpty) {
      return null;
    }

    final segments = <String>[];
    for (var index = 0; index < node.arguments.length; index++) {
      final rawSegment = _stringifyArgument(node, index).trim();
      if (rawSegment.isEmpty) {
        continue;
      }

      if (index == 0) {
        segments.add(rawSegment);
        continue;
      }

      final numericIndex = int.tryParse(rawSegment);
      if (numericIndex != null) {
        final current = segments.isEmpty ? r'$' : segments.removeLast();
        segments.add('$current[$numericIndex]');
        continue;
      }

      segments.add(rawSegment);
    }

    if (segments.isEmpty) {
      return null;
    }
    return r'$.' + segments.join('.');
  }

  Action _buildSetScopedVariableAction({
    required String scope,
    required BdfdFunctionCallAst node,
  }) {
    final key = _normalizeScopedVariableKey(_stringifyArgument(node, 0));
    final value = _stringifyArgument(node, 1);
    final contextId =
        node.arguments.length > 2 ? _stringifyArgument(node, 2).trim() : '';

    if (key.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'Scoped variable name cannot be empty for ${node.name}.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
    }

    return Action(
      type: BotCreatorActionType.setScopedVariable,
      payload: <String, dynamic>{
        'scope': scope,
        'key': key,
        'valueType': 'string',
        'value': value,
        if (contextId.isNotEmpty) 'contextId': contextId,
      },
    );
  }

  Action _buildSetTemporaryVariableAction(BdfdFunctionCallAst node) {
    final key = _normalizeScopedVariableKey(_stringifyArgument(node, 0));
    final value = _stringifyArgument(node, 1);
    if (key.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'Temporary variable name cannot be empty for ${node.name}.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
    }

    return Action(
      type: BotCreatorActionType.setTemporaryVariable,
      payload: <String, dynamic>{
        'key': key,
        'valueType': 'string',
        'value': value,
      },
    );
  }

  Action _buildAwaitFuncAction(BdfdFunctionCallAst node) {
    final awaitNameRaw = _stringifyArgument(node, 0).trim();
    final awaitName = _normalizeAwaitName(awaitNameRaw);
    if (awaitName.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'Await function name cannot be empty for ${node.name}.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
    }

    var userId = _stringifyArgument(node, 1).trim();
    var channelId = _stringifyArgument(node, 2).trim();

    if (userId.startsWith('(')) {
      userId = userId.substring(1).trim();
    }
    if (userId.endsWith(')')) {
      userId = userId.substring(0, userId.length - 1).trim();
    }
    if (channelId.startsWith('(')) {
      channelId = channelId.substring(1).trim();
    }
    if (channelId.endsWith(')')) {
      channelId = channelId.substring(0, channelId.length - 1).trim();
    }

    final payloadMap = <String, String>{
      'name': awaitName,
      'userId': userId.isEmpty ? '((author.id))' : userId,
      'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    return Action(
      type: BotCreatorActionType.setScopedVariable,
      payload: <String, dynamic>{
        'scope': 'user',
        'key': 'await_$awaitName',
        'valueType': 'json',
        'jsonValue': jsonEncode(payloadMap),
      },
    );
  }

  String _inlineCheckUserPerms(BdfdFunctionCallAst node) {
    final parsed = _buildCheckUserPermsCondition(node);
    if (parsed == null) {
      return '';
    }

    final key = 'check_user_perms_${_permissionCheckCounter++}';
    _deferredInlineActions.add(
      _buildGuardIfAction(
        condition: parsed.condition,
        thenActions: <Action>[
          _buildSetScopedVariableActionRaw(
            scope: 'message',
            key: key,
            value: 'true',
          ),
        ],
        elseActions: <Action>[
          _buildSetScopedVariableActionRaw(
            scope: 'message',
            key: key,
            value: 'false',
          ),
        ],
      ),
    );

    return _scopedVariablePlaceholder('message', key);
  }

  String _inlineMessageArgument(BdfdFunctionCallAst node) {
    final first = _stringifyArgument(node, 0).trim();
    final second = _stringifyArgument(node, 1).trim();

    if (first.isEmpty && second.isEmpty) {
      return '((message.content))';
    }

    final messageExpression = _messageArgumentExpression(first);
    final optionSource =
        second.isNotEmpty ? second : (messageExpression == null ? first : '');
    final optionExpression = _optionExpression(optionSource);

    if (messageExpression != null && optionExpression != null) {
      return '(($messageExpression|$optionExpression))';
    }
    if (messageExpression != null) {
      return '(($messageExpression))';
    }
    if (optionExpression != null) {
      return '(($optionExpression))';
    }

    return '((message.content))';
  }

  String _inlineArgsArgument(BdfdFunctionCallAst node) {
    final first = _stringifyArgument(node, 0).trim();
    final second = _stringifyArgument(node, 1).trim();

    if (first.isEmpty && second.isEmpty) {
      return '((message.content))';
    }

    final argsExpression = _argsArgumentExpression(first);
    final optionSource =
        second.isNotEmpty ? second : (argsExpression == null ? first : '');
    final optionExpression = _optionExpression(optionSource);

    if (argsExpression != null && optionExpression != null) {
      return '(($argsExpression|$optionExpression))';
    }
    if (argsExpression != null) {
      return '(($argsExpression))';
    }
    if (optionExpression != null) {
      return '(($optionExpression))';
    }

    return '((message.content))';
  }

  String? _argsArgumentExpression(String rawIndex) {
    final trimmed = rawIndex.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed == '>') {
      return 'last(split(message.content, " "))';
    }

    final parsedIndex = int.tryParse(trimmed);
    if (parsedIndex == null || parsedIndex < 0) {
      return null;
    }

    if (parsedIndex == 0) {
      return 'args.0';
    }

    final zeroBasedIndex = parsedIndex - 1;
    return 'message.content[$zeroBasedIndex]|args.$parsedIndex';
  }

  String? _messageArgumentExpression(String rawIndex) {
    final trimmed = rawIndex.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed == '>') {
      return 'last(split(message.content, " "))';
    }

    final parsedIndex = int.tryParse(trimmed);
    if (parsedIndex == null || parsedIndex < 0) {
      return null;
    }

    if (parsedIndex == 0) {
      return 'args.0';
    }

    final zeroBasedIndex = parsedIndex - 1;
    return 'message.content[$zeroBasedIndex]';
  }

  String? _optionExpression(String rawOptionName) {
    final trimmed = rawOptionName.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final normalized =
        trimmed.startsWith('opts.') ? trimmed.substring(5) : trimmed;
    if (normalized.isEmpty) {
      return null;
    }

    return 'opts.$normalized';
  }

  String _inlineMentionedChannels(BdfdFunctionCallAst node) {
    final mentionRaw = _stringifyArgument(node, 0).trim();
    final mentionNumber = int.tryParse(mentionRaw);
    if (mentionNumber == null || mentionNumber <= 0) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a positive mention number.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return '';
    }

    final zeroBasedIndex = mentionNumber - 1;
    final mentionExpression = 'message.mentions[$zeroBasedIndex]';
    final returnCurrentRaw = _stringifyArgument(node, 1).trim();
    final returnCurrent =
        returnCurrentRaw.isNotEmpty && _parseBooleanLike(returnCurrentRaw);

    if (returnCurrent) {
      return '(($mentionExpression|channel.id))';
    }
    return '(($mentionExpression))';
  }

  Action _buildSetScopedVariableActionRaw({
    required String scope,
    required String key,
    required String value,
  }) {
    return Action(
      type: BotCreatorActionType.setScopedVariable,
      payload: <String, dynamic>{
        'scope': scope,
        'key': key,
        'valueType': 'string',
        'value': value,
      },
    );
  }

  String _normalizeAwaitName(String raw) {
    final lowered = raw.trim().toLowerCase();
    if (lowered.isEmpty) {
      return '';
    }
    return lowered.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  String _scopedVariablePlaceholder(
    String scope,
    String rawKey, [
    String? contextId,
  ]) {
    final trimmedKey = rawKey.trim();
    final key = _normalizeScopedVariableKey(trimmedKey);
    if (key.isEmpty) {
      return '';
    }
    if (scope == 'temp') {
      return '((temp.$key))';
    }

    final id = contextId?.trim();
    if (id != null && id.isNotEmpty) {
      return '(($scope[$id].bc_$key))';
    }

    if (_containsRuntimePlaceholder(trimmedKey)) {
      return '(($scope.bc_$trimmedKey|$scope.$trimmedKey))';
    }
    return '(($scope.bc_$key))';
  }

  bool _containsRuntimePlaceholder(String value) {
    return value.contains('((');
  }

  String _buildRuntimeBracketExpression(String name, List<String> args) {
    return '(($name[${args.join(';')}]))';
  }

  String _normalizeScopedVariableKey(String rawKey) {
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('bc_')) {
      return trimmed.substring(3);
    }
    return trimmed;
  }

  String _rebuildFunctionSource(BdfdFunctionCallAst node) {
    final functionName =
        node.name.startsWith(r'$') ? node.name : '${r'$'}${node.name}';

    if (node.arguments.isEmpty) {
      return functionName;
    }

    final arguments = node.arguments.map(_stringifyNodes).join(';');
    return '$functionName[$arguments]';
  }

  Action _buildRespondWithMessageAction({
    String content = '',
    List<Map<String, dynamic>> embeds = const <Map<String, dynamic>>[],
  }) {
    return Action(
      type: BotCreatorActionType.respondWithMessage,
      payload: <String, dynamic>{
        'content': content,
        'embeds': embeds,
        'components': const <String, dynamic>{},
        'ephemeral': false,
      },
    );
  }
}
