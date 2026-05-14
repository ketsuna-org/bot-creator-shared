import 'dart:convert';
import 'dart:math';

final _random = Random();

class _ResolvedExpression {
  const _ResolvedExpression({required this.found, this.value});

  final bool found;
  final dynamic value;
}

List<Object>? _parseJsonPathSegments(String rawPath) {
  var path = rawPath.trim();
  if (path.isEmpty) {
    return null;
  }

  if (path.startsWith(r'$.')) {
    path = path.substring(2);
  } else if (path.startsWith(r'$')) {
    path = path.substring(1);
  }

  if (path.isEmpty) {
    return const <Object>[];
  }

  final segments = <Object>[];
  final token = StringBuffer();

  void flushToken() {
    if (token.isNotEmpty) {
      segments.add(token.toString());
      token.clear();
    }
  }

  for (var index = 0; index < path.length; index++) {
    final char = path[index];
    if (char == '.') {
      flushToken();
      continue;
    }

    if (char == '[') {
      flushToken();
      final closing = path.indexOf(']', index + 1);
      if (closing == -1) {
        return null;
      }
      final indexText = path.substring(index + 1, closing).trim();
      final listIndex = int.tryParse(indexText);
      if (listIndex == null) {
        return null;
      }
      segments.add(listIndex);
      index = closing;
      continue;
    }

    token.write(char);
  }

  flushToken();
  return segments;
}

List<Object>? parseJsonPathSegments(String rawPath) {
  return _parseJsonPathSegments(rawPath);
}

dynamic extractJsonPathValue(dynamic data, String rawPath) {
  final segments = _parseJsonPathSegments(rawPath);
  if (segments == null) {
    return null;
  }

  dynamic current = data;
  for (final segment in segments) {
    if (segment is String) {
      if (segment.isEmpty) {
        continue;
      }
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

String _stringifyResolvedValue(dynamic value) {
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

dynamic decodeJsonStringIfNeeded(dynamic value) {
  if (value is! String) {
    return value;
  }

  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return value;
  }

  final looksJson =
      (trimmed.startsWith('[') && trimmed.endsWith(']')) ||
      (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
      trimmed == 'null';
  if (!looksJson) {
    return value;
  }

  try {
    return jsonDecode(trimmed);
  } catch (_) {
    return value;
  }
}

String? _lookupVariableValue(String key, Map<String, String> updates) {
  final val = updates[key];
  if (val != null) {
    return val;
  }
  
  print('DEBUG: Variable lookup failed for key: "$key"');
  print('DEBUG: First 5 keys in updates: ${updates.keys.take(5).toList()}');

  final loweredKey = key.toLowerCase();
  for (final entry in updates.entries) {
    if (entry.key.toLowerCase() == loweredKey) {
      return entry.value;
    }
  }

  // Dynamic time variables resolved at template evaluation time.
  if (loweredKey == 'gettimestamp') {
    return (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000).toString();
  }
  if (loweredKey == 'gettimestampms') {
    return DateTime.now().toUtc().millisecondsSinceEpoch.toString();
  }

  return null;
}

bool _isMeaningfulResolvedValue(dynamic value) {
  if (value == null) {
    return false;
  }
  if (value is String) {
    return value.trim().isNotEmpty;
  }
  return true;
}

bool _looksLikeLiteralFallback(String expression) {
  final trimmed = expression.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (_isWrappedStringLiteral(trimmed)) {
    return true;
  }
  return RegExp(r'^[^A-Za-z0-9_.$\[\]()]+$').hasMatch(trimmed);
}

dynamic _resolveComputedVariableValue(String key, Map<String, String> updates) {
  final markerIndex = key.lastIndexOf('.\$');
  if (markerIndex == -1) {
    return null;
  }

  final bodyVariableKey = key.substring(0, markerIndex);
  final jsonPathRaw = key.substring(markerIndex + 1);
  if (!jsonPathRaw.startsWith(r'$')) {
    return null;
  }

  final rawBody = _lookupVariableValue(bodyVariableKey, updates);
  if (rawBody == null || rawBody.isEmpty) {
    return null;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(rawBody);
  } catch (_) {
    return null;
  }

  return extractJsonPathValue(decoded, jsonPathRaw);
}

List<String> _splitTopLevel(String input, String delimiter) {
  final parts = <String>[];
  final buffer = StringBuffer();
  var parenthesisDepth = 0;
  var bracketDepth = 0;
  String? quote;
  var escaping = false;

  for (var index = 0; index < input.length; index++) {
    final char = input[index];

    if (quote != null) {
      buffer.write(char);
      if (escaping) {
        escaping = false;
      } else if (char == r'\') {
        escaping = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }

    if (char == '"' || char == "'") {
      quote = char;
      buffer.write(char);
      continue;
    }

    if (char == '(') {
      parenthesisDepth++;
      buffer.write(char);
      continue;
    }

    if (char == ')') {
      if (parenthesisDepth > 0) {
        parenthesisDepth--;
      }
      buffer.write(char);
      continue;
    }

    if (char == '[') {
      bracketDepth++;
      buffer.write(char);
      continue;
    }

    if (char == ']') {
      if (bracketDepth > 0) {
        bracketDepth--;
      }
      buffer.write(char);
      continue;
    }

    if (parenthesisDepth == 0 &&
        bracketDepth == 0 &&
        input.startsWith(delimiter, index)) {
      parts.add(buffer.toString());
      buffer.clear();
      index += delimiter.length - 1;
      continue;
    }

    buffer.write(char);
  }

  parts.add(buffer.toString());
  return parts;
}

String _unescapeStringLiteral(String body) {
  final buffer = StringBuffer();
  for (var index = 0; index < body.length; index++) {
    final char = body[index];
    if (char != r'\' || index + 1 >= body.length) {
      buffer.write(char);
      continue;
    }

    final next = body[++index];
    switch (next) {
      case 'n':
        buffer.write('\n');
        break;
      case 'r':
        buffer.write('\r');
        break;
      case 't':
        buffer.write('\t');
        break;
      case r'\':
        buffer.write(r'\');
        break;
      case '"':
        buffer.write('"');
        break;
      case "'":
        buffer.write("'");
        break;
      default:
        buffer
          ..write(r'\')
          ..write(next);
        break;
    }
  }
  return buffer.toString();
}

String _toTitleCase(String input) {
  if (input.isEmpty) {
    return '';
  }

  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  var shouldUppercaseNext = true;

  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final isLetterOrDigit = RegExp(r'[a-z0-9]').hasMatch(char);
    if (!isLetterOrDigit) {
      shouldUppercaseNext = true;
      buffer.write(char);
      continue;
    }

    if (shouldUppercaseNext) {
      buffer.write(char.toUpperCase());
      shouldUppercaseNext = false;
    } else {
      buffer.write(char);
    }
  }

  return buffer.toString();
}

int _countLines(String input) {
  if (input.isEmpty) {
    return 0;
  }
  return input.replaceAll('\r\n', '\n').split('\n').length;
}

String _formatNumberWithSeparator(num value, String separator) {
  final parts = value.toString().split('.');
  final integerPart = parts[0];
  final decimalPart = parts.length > 1 ? parts[1] : '';

  final sign = integerPart.startsWith('-') ? '-' : '';
  final digits = sign.isEmpty ? integerPart : integerPart.substring(1);
  final grouped = <String>[];

  for (var i = digits.length; i > 0; i -= 3) {
    final start = (i - 3).clamp(0, digits.length);
    grouped.add(digits.substring(start, i));
  }

  final joined = grouped.reversed.join(separator);
  if (decimalPart.isEmpty) {
    return '$sign$joined';
  }
  return '$sign$joined.$decimalPart';
}

bool _isWrappedStringLiteral(String input) {
  if (input.length < 2) {
    return false;
  }
  final quote = input[0];
  if ((quote != '"' && quote != "'") || input[input.length - 1] != quote) {
    return false;
  }

  var escaping = false;
  for (var index = 1; index < input.length - 1; index++) {
    final char = input[index];
    if (escaping) {
      escaping = false;
      continue;
    }
    if (char == r'\') {
      escaping = true;
      continue;
    }
    if (char == quote) {
      return false;
    }
  }

  return true;
}

({String name, String inner})? _parseFunctionCall(String expression) {
  final openIndex = expression.indexOf('(');
  if (openIndex <= 0 || !expression.endsWith(')')) {
    return null;
  }

  final name = expression.substring(0, openIndex).trim();
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
    return null;
  }

  var depth = 0;
  String? quote;
  var escaping = false;
  for (var index = openIndex; index < expression.length; index++) {
    final char = expression[index];

    if (quote != null) {
      if (escaping) {
        escaping = false;
      } else if (char == r'\') {
        escaping = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }

    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }

    if (char == '(') {
      depth++;
      continue;
    }

    if (char == ')') {
      depth--;
      if (depth == 0 && index != expression.length - 1) {
        return null;
      }
      if (depth < 0) {
        return null;
      }
    }
  }

  if (depth != 0) {
    return null;
  }

  return (
    name: name,
    inner: expression.substring(openIndex + 1, expression.length - 1),
  );
}

_ResolvedExpression? _resolveBracketCollectionVariableValue(
  String key,
  Map<String, String> updates,
) {
  final openIndex = key.lastIndexOf('[');
  if (openIndex <= 0 || !key.endsWith(']')) {
    return null;
  }

  final baseKey = key.substring(0, openIndex).trim();
  if (baseKey.isEmpty) {
    return null;
  }

  final rawCollection = _lookupVariableValue('__collection.$baseKey', updates);
  if (rawCollection == null || rawCollection.isEmpty) {
    return null;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(rawCollection);
  } catch (_) {
    return null;
  }

  if (decoded is! List) {
    return null;
  }

  final items = decoded.map(_stringifyResolvedValue).toList(growable: false);
  final spec = key.substring(openIndex + 1, key.length - 1);
  final trimmedSpec = spec.trim();

  final numericIndex = int.tryParse(trimmedSpec);
  if (numericIndex != null) {
    final zeroBasedIndex = numericIndex - 1;
    if (zeroBasedIndex < 0 || zeroBasedIndex >= items.length) {
      return const _ResolvedExpression(found: true, value: '');
    }
    return _ResolvedExpression(found: true, value: items[zeroBasedIndex]);
  }

  if (trimmedSpec.isEmpty) {
    return const _ResolvedExpression(found: true, value: '');
  }

  final separatorIndex = spec.indexOf(';');
  final separator =
      separatorIndex == -1 ? spec : spec.substring(0, separatorIndex);
  final limitRaw =
      separatorIndex == -1 ? '' : spec.substring(separatorIndex + 1).trim();
  final limit = int.tryParse(limitRaw);
  final boundedItems =
      limit == null || limit < 0
          ? items
          : items.take(limit).toList(growable: false);
  return _ResolvedExpression(found: true, value: boundedItems.join(separator));
}

({String name, String inner})? _parseBracketFunctionCall(String expression) {
  final openIndex = expression.indexOf('[');
  if (openIndex <= 0 || !expression.endsWith(']')) {
    return null;
  }

  final name = expression.substring(0, openIndex).trim();
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
    return null;
  }

  var depth = 0;
  String? quote;
  var escaping = false;
  for (var index = openIndex; index < expression.length; index++) {
    final char = expression[index];

    if (quote != null) {
      if (escaping) {
        escaping = false;
      } else if (char == r'\') {
        escaping = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }

    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }

    if (char == '[') {
      depth++;
      continue;
    }

    if (char == ']') {
      depth--;
      if (depth == 0 && index != expression.length - 1) {
        return null;
      }
      if (depth < 0) {
        return null;
      }
    }
  }

  if (depth != 0) {
    return null;
  }

  return (
    name: name,
    inner: expression.substring(openIndex + 1, expression.length - 1),
  );
}

double? _evaluateSimpleMathExpression(String expression) {
  final cleaned = expression.replaceAll(' ', '');
  if (cleaned.isEmpty) {
    return null;
  }

  final directNum = double.tryParse(cleaned);
  if (directNum != null) {
    return directNum;
  }

  final twoOperandPattern = RegExp(r'^(-?[\d.]+)\s*([+\-*/%^])\s*(-?[\d.]+)$');
  final match = twoOperandPattern.firstMatch(cleaned);
  if (match == null) {
    return null;
  }

  final left = double.tryParse(match.group(1)!);
  final operator = match.group(2)!;
  final right = double.tryParse(match.group(3)!);
  if (left == null || right == null) {
    return null;
  }

  switch (operator) {
    case '+':
      return left + right;
    case '-':
      return left - right;
    case '*':
      return left * right;
    case '/':
      return right != 0 ? left / right : 0;
    case '%':
      return right != 0 ? left % right : 0;
    case '^':
      return pow(left, right).toDouble();
    default:
      return null;
  }
}

dynamic _applyBdfdBracketFunction(
  String rawName,
  List<String> rawArgs,
  List<dynamic> resolvedArgs,
  Map<String, String> updates,
) {
  final name = rawName.trim().toLowerCase();
  switch (name) {
    case 'calculate':
      if (rawArgs.isEmpty) {
        return null;
      }
      final expression =
          resolveTemplatePlaceholders(rawArgs.first, updates).trim();
      final result = _evaluateSimpleMathExpression(expression);
      if (result == null) {
        return null;
      }
      return _normalizeNumericResult(result);
    case 'ceil':
      final ceilValue =
          resolvedArgs.isEmpty ? null : _coerceNum(resolvedArgs[0]);
      return ceilValue?.ceil();
    case 'floor':
      final floorValue =
          resolvedArgs.isEmpty ? null : _coerceNum(resolvedArgs[0]);
      return floorValue?.floor();
    case 'round':
      final roundValue =
          resolvedArgs.isEmpty ? null : _coerceNum(resolvedArgs[0]);
      return roundValue?.round();
    case 'sqrt':
      final sqrtValue =
          resolvedArgs.isEmpty ? null : _coerceNum(resolvedArgs[0]);
      if (sqrtValue == null) {
        return null;
      }
      return _normalizeNumericResult(sqrt(sqrtValue.toDouble()));
    case 'max':
      if (resolvedArgs.length < 2) {
        return null;
      }
      final left = _coerceNum(resolvedArgs[0]);
      final right = _coerceNum(resolvedArgs[1]);
      if (left == null || right == null) {
        return null;
      }
      return _normalizeNumericResult(max(left, right));
    case 'min':
      if (resolvedArgs.length < 2) {
        return null;
      }
      final left = _coerceNum(resolvedArgs[0]);
      final right = _coerceNum(resolvedArgs[1]);
      if (left == null || right == null) {
        return null;
      }
      return _normalizeNumericResult(min(left, right));
    case 'modulo':
    case 'multi':
    case 'divide':
    case 'sub':
      if (resolvedArgs.length < 2) {
        return null;
      }
      final left = _coerceNum(resolvedArgs[0]);
      final right = _coerceNum(resolvedArgs[1]);
      if (left == null || right == null) {
        return null;
      }
      switch (name) {
        case 'modulo':
          return _normalizeNumericResult(right != 0 ? left % right : 0);
        case 'multi':
          return _normalizeNumericResult(left * right);
        case 'divide':
          return _normalizeNumericResult(right != 0 ? left / right : 0);
        case 'sub':
          return _normalizeNumericResult(left - right);
      }
      return null;
    case 'totitlecase':
    case 'tolowercase':
    case 'touppercase':
    case 'charcount':
    case 'linescount':
    case 'croptext':
      return _applyFunction(name, resolvedArgs, updates);
    case 'bytecount':
      if (resolvedArgs.isEmpty) {
        return null;
      }
      return utf8.encode(_stringifyResolvedValue(resolvedArgs.first)).length;
    case 'trimcontent':
    case 'trimspace':
      if (resolvedArgs.isEmpty) {
        return null;
      }
      return _stringifyResolvedValue(resolvedArgs.first).trim();
    case 'sum':
      if (resolvedArgs.isEmpty) {
        return null;
      }
      if (resolvedArgs.length == 1) {
        final source = _coerceList(resolvedArgs[0]);
        if (source != null) {
          num total = 0;
          for (final item in source) {
            final numeric = _coerceNum(item);
            if (numeric != null) {
              total += numeric;
            }
          }
          return _normalizeNumericResult(total);
        }
      }
      num total = 0;
      var foundNumeric = false;
      for (final arg in resolvedArgs) {
        final numeric = _coerceNum(arg);
        if (numeric == null) {
          return null;
        }
        foundNumeric = true;
        total += numeric;
      }
      return foundNumeric ? _normalizeNumericResult(total) : null;
    case 'random':
      if (resolvedArgs.length < 2) {
        return _random.nextBool() ? 'true' : '';
      }
      final min = _coerceInt(resolvedArgs[0]);
      final max = _coerceInt(resolvedArgs[1]);
      if (min == null || max == null || max < min) {
        return null;
      }
      return min + _random.nextInt(max - min + 1);
    case 'randomtext':
      if (resolvedArgs.isEmpty) {
        return '';
      }
      return _stringifyResolvedValue(resolvedArgs[_random.nextInt(resolvedArgs.length)]);
    case 'date':
      final now = DateTime.now().toUtc();
      return '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
    default:
      return null;
  }
}

dynamic _normalizeNumericResult(num value) {
  if (value is int) {
    return value;
  }
  if (value is double && value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toInt();
  }
  return value;
}

int? _coerceInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_stringifyResolvedValue(value).trim());
}

num? _coerceNum(dynamic value) {
  if (value is num) {
    return value;
  }
  return num.tryParse(_stringifyResolvedValue(value).trim());
}

bool _coerceBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }

  final text = _stringifyResolvedValue(value).trim().toLowerCase();
  if (text == 'true') {
    return true;
  }
  if (text == 'false') {
    return false;
  }
  return fallback;
}

List<dynamic>? _coerceList(dynamic value) {
  final decoded = decodeJsonStringIfNeeded(value);
  if (decoded is List) {
    return List<dynamic>.from(decoded);
  }
  return null;
}

const Set<String> _discordMediaFormats = <String>{
  'png',
  'jpg',
  'jpeg',
  'webp',
  'gif',
};

String _normalizeDiscordMediaFormat(dynamic value, {String fallback = 'webp'}) {
  final normalized = _stringifyResolvedValue(value).trim().toLowerCase();
  if (_discordMediaFormats.contains(normalized)) {
    return normalized;
  }
  return fallback;
}

int _normalizeDiscordMediaSize(dynamic value, {int fallback = 1024}) {
  final parsed = _coerceInt(value) ?? fallback;
  final bounded = parsed.clamp(16, 4096);
  return bounded;
}

String _applyDiscordMediaOptions(
  dynamic rawUrl, {
  dynamic format,
  dynamic size,
}) {
  final source = _stringifyResolvedValue(rawUrl).trim();
  if (source.isEmpty) {
    return '';
  }

  final uri = Uri.tryParse(source);
  if (uri == null) {
    return source;
  }

  final normalizedFormat = _normalizeDiscordMediaFormat(format);
  final normalizedSize = _normalizeDiscordMediaSize(size);
  final segments = List<String>.from(uri.pathSegments);
  if (segments.isNotEmpty) {
    final last = segments.last;
    final dotIndex = last.lastIndexOf('.');
    if (dotIndex > 0 && dotIndex < last.length - 1) {
      segments[segments.length - 1] =
          '${last.substring(0, dotIndex)}.$normalizedFormat';
    }
  }

  final queryParameters = Map<String, String>.from(uri.queryParameters);
  queryParameters['size'] = normalizedSize.toString();

  return uri
      .replace(pathSegments: segments, queryParameters: queryParameters)
      .toString();
}

String _resolveItemPlaceholderValue(dynamic item, String rawPath) {
  final path = rawPath.trim();
  if (path.isEmpty) {
    return '';
  }

  if (path == 'value') {
    return _stringifyResolvedValue(item);
  }

  final composedPath =
      path.startsWith(r'$')
          ? path
          : path.startsWith('[')
          ? '\$$path'
          : '\$.$path';
  return _stringifyResolvedValue(extractJsonPathValue(item, composedPath));
}

String resolveItemTemplate(
  String template,
  dynamic item,
  Map<String, String> updates,
) {
  final interpolated = template.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (
    match,
  ) {
    return _resolveItemPlaceholderValue(item, match.group(1)!);
  });
  return resolveTemplatePlaceholders(interpolated, updates);
}

dynamic _applyFunction(
  String rawName,
  List<dynamic> args,
  Map<String, String> updates,
) {
  final name = rawName.trim().toLowerCase();
  switch (name) {
    case 'titlecase':
    case 'totitlecase':
    case 'title':
      if (args.isEmpty) {
        return null;
      }
      return _toTitleCase(_stringifyResolvedValue(args.first));
    case 'lower':
    case 'lowercase':
    case 'tolowercase':
      if (args.isEmpty) {
        return null;
      }
      return _stringifyResolvedValue(args.first).toLowerCase();
    case 'upper':
    case 'uppercase':
    case 'touppercase':
      if (args.isEmpty) {
        return null;
      }
      return _stringifyResolvedValue(args.first).toUpperCase();
    case 'trim':
      if (args.isEmpty) {
        return null;
      }
      return _stringifyResolvedValue(args.first).trim();
    case 'replace':
      if (args.length < 3) {
        return null;
      }
      final source = _stringifyResolvedValue(args[0]);
      final search = _stringifyResolvedValue(args[1]);
      final replacement = _stringifyResolvedValue(args[2]);
      return source.replaceAll(search, replacement);
    case 'contains':
      if (args.length < 2) {
        return null;
      }
      final haystack = _stringifyResolvedValue(args[0]).toLowerCase();
      final needle = _stringifyResolvedValue(args[1]).toLowerCase();
      return haystack.contains(needle) ? 'true' : '';
    case 'length':
    case 'charcount':
    case 'charcounts':
      if (args.isEmpty) {
        return null;
      }
      final value = decodeJsonStringIfNeeded(args.first);
      if (value is List || value is Map || value is String) {
        return value.length;
      }
      return null;
    case 'linescount':
      if (args.isEmpty) {
        return null;
      }
      return _countLines(_stringifyResolvedValue(args.first));
    case 'numberseparator':
      if (args.isEmpty) {
        return null;
      }
      final value = _coerceNum(args.first);
      if (value == null) {
        return null;
      }
      final separator =
          args.length >= 2 ? _stringifyResolvedValue(args[1]) : ',';
      return _formatNumberWithSeparator(value, separator);
    case 'split':
      if (args.length < 2) {
        return null;
      }
      final source = _stringifyResolvedValue(args[0]);
      final separator = _stringifyResolvedValue(args[1]);
      final parts =
          separator.isEmpty ? source.split('') : source.split(separator);
      if (args.length < 3) {
        return parts;
      }
      final index = _coerceInt(args[2]);
      if (index == null || index < 0 || index >= parts.length) {
        return null;
      }
      return parts[index];
    case 'at':
      if (args.length < 2) {
        return null;
      }
      final source = _coerceList(args[0]);
      final index = _coerceInt(args[1]);
      if (source == null || index == null) {
        return null;
      }
      if (index < 0 || index >= source.length) {
        return null;
      }
      return source[index];
    case 'first':
      if (args.isEmpty) {
        return null;
      }
      final source = _coerceList(args[0]);
      if (source == null || source.isEmpty) {
        return null;
      }
      return source.first;
    case 'last':
      if (args.isEmpty) {
        return null;
      }
      final source = _coerceList(args[0]);
      if (source == null || source.isEmpty) {
        return null;
      }
      return source.last;
    case 'slice':
    case 'crop':
    case 'croptext':
      if (args.length < 2) {
        return null;
      }
      final start = _coerceInt(args[1]);
      if (start == null) {
        return null;
      }

      if (name == 'crop' || name == 'croptext') {
        final source = _stringifyResolvedValue(args[0]);
        final maxLength = start;
        if (maxLength < 0) {
          return null;
        }
        final suffix =
            args.length >= 3 ? _stringifyResolvedValue(args[2]) : '...';
        if (source.length <= maxLength) {
          return source;
        }
        if (maxLength == 0) {
          return '';
        }
        return source.substring(0, maxLength) + suffix;
      }

      final end = args.length >= 3 ? _coerceInt(args[2]) : null;

      final sourceList = _coerceList(args[0]);
      if (sourceList != null) {
        final safeStart = start.clamp(0, sourceList.length);
        final safeEnd = (end ?? sourceList.length).clamp(
          safeStart,
          sourceList.length,
        );
        return sourceList.sublist(safeStart, safeEnd);
      }

      final sourceString = _stringifyResolvedValue(args[0]);
      if (sourceString.isEmpty) {
        return '';
      }
      final safeStart = start.clamp(0, sourceString.length);
      final safeEnd = (end ?? sourceString.length).clamp(
        safeStart,
        sourceString.length,
      );
      return sourceString.substring(safeStart, safeEnd);
    case 'join':
      if (args.length < 2) {
        return null;
      }
      final source = _coerceList(args[0]);
      if (source == null) {
        return null;
      }
      final separator = _stringifyResolvedValue(args[1]);
      return source.map(_stringifyResolvedValue).join(separator);
    case 'sum':
      if (args.isEmpty) {
        return null;
      }
      final source = _coerceList(args[0]);
      if (source == null) {
        return null;
      }
      num total = 0;
      for (final item in source) {
        final numeric = _coerceNum(item);
        if (numeric != null) {
          total += numeric;
        }
      }
      return total;
    case 'formateach':
      if (args.length < 3) {
        return null;
      }
      final source = _coerceList(args[0]);
      if (source == null) {
        return null;
      }
      final itemTemplate = _stringifyResolvedValue(args[1]);
      final separator = _stringifyResolvedValue(args[2]);
      return source
          .map((item) => resolveItemTemplate(itemTemplate, item, updates))
          .join(separator);
    case 'embedfields':
      if (args.length < 3) {
        return null;
      }
      final source = _coerceList(args[0]);
      if (source == null) {
        return null;
      }
      final nameTemplate = _stringifyResolvedValue(args[1]);
      final valueTemplate = _stringifyResolvedValue(args[2]);
      final isInline = args.length >= 4 ? _coerceBool(args[3]) : false;
      final fields = <Map<String, dynamic>>[];
      for (final item in source) {
        final fieldName = resolveItemTemplate(nameTemplate, item, updates);
        final fieldValue = resolveItemTemplate(valueTemplate, item, updates);
        if (fieldName.isEmpty || fieldValue.isEmpty) {
          continue;
        }
        fields.add(<String, dynamic>{
          'name': fieldName,
          'value': fieldValue,
          'inline': isInline,
        });
      }
      return fields;
    case 'avatar':
      if (args.isEmpty) {
        return null;
      }
      return _applyDiscordMediaOptions(
        args.first,
        format: args.length >= 2 ? args[1] : 'webp',
        size: args.length >= 3 ? args[2] : 1024,
      );
    case 'banner':
      if (args.isEmpty) {
        return null;
      }
      return _applyDiscordMediaOptions(
        args.first,
        format: args.length >= 2 ? args[1] : 'webp',
        size: args.length >= 3 ? args[2] : 1024,
      );
    case 'coin':
    case 'random':
      // coin() / random() → random bool ("true" or "")
      // Use coin() in conditionals for true/false branching.
      // random() is kept as a legacy alias.
      return _random.nextBool() ? 'true' : '';
    case 'randomchoice':
      // randomchoice("a", "b", "c") → picks one at random
      if (args.isEmpty) {
        return null;
      }
      return args[_random.nextInt(args.length)];
    case 'randomint':
      // randomint(min, max) → random integer in [min, max]
      if (args.length < 2) {
        return null;
      }
      final min = _coerceInt(args[0]);
      final max = _coerceInt(args[1]);
      if (min == null || max == null || max < min) {
        return null;
      }
      return min + _random.nextInt(max - min + 1);
    default:
      return null;
  }
}

_ResolvedExpression _evaluateSingleExpression(
  String expression,
  Map<String, String> updates,
) {
  final trimmed = expression.trim();
  if (trimmed.isEmpty) {
    return const _ResolvedExpression(found: true, value: '');
  }

  if (_isWrappedStringLiteral(trimmed)) {
    return _ResolvedExpression(
      found: true,
      value: _unescapeStringLiteral(trimmed.substring(1, trimmed.length - 1)),
    );
  }

  if (trimmed == 'null') {
    return const _ResolvedExpression(found: true, value: null);
  }
  if (trimmed == 'true') {
    return const _ResolvedExpression(found: true, value: true);
  }
  if (trimmed == 'false') {
    return const _ResolvedExpression(found: true, value: false);
  }

  final number = num.tryParse(trimmed);
  if (number != null) {
    return _ResolvedExpression(found: true, value: number);
  }

  final functionCall = _parseFunctionCall(trimmed);
  if (functionCall != null) {
    final args = _splitTopLevel(functionCall.inner, ',');
    final resolvedArgs = <dynamic>[];
    for (final arg in args) {
      final outcome = _evaluateExpression(arg, updates);
      if (!outcome.found) {
        return const _ResolvedExpression(found: false);
      }
      resolvedArgs.add(outcome.value);
    }
    final value = _applyFunction(functionCall.name, resolvedArgs, updates);
    if (value == null && functionCall.name.trim().toLowerCase() != 'length') {
      return const _ResolvedExpression(found: false);
    }
    return _ResolvedExpression(found: true, value: value);
  }

  final bracketFunctionCall = _parseBracketFunctionCall(trimmed);
  if (bracketFunctionCall != null) {
    final rawArgs = _splitTopLevel(bracketFunctionCall.inner, ';');
    final resolvedArgs = <dynamic>[];
    for (final arg in rawArgs) {
      final outcome = _evaluateExpression(arg, updates);
      if (!outcome.found) {
        return const _ResolvedExpression(found: false);
      }
      resolvedArgs.add(outcome.value);
    }
    final value = _applyBdfdBracketFunction(
      bracketFunctionCall.name,
      rawArgs,
      resolvedArgs,
      updates,
    );
    if (value != null) {
      return _ResolvedExpression(found: true, value: value);
    }
  }

  String resolvedKey = trimmed;
  if (trimmed.contains('((')) {
    final nestedResolved = resolveTemplatePlaceholders(trimmed, updates).trim();
    if (nestedResolved.isNotEmpty) {
      resolvedKey = nestedResolved;
      if (trimmed.startsWith('((') && trimmed.endsWith('))')) {
        return _ResolvedExpression(found: true, value: resolvedKey);
      }
    }
  }

  final direct = _lookupVariableValue(resolvedKey, updates);
  if (direct != null) {
    return _ResolvedExpression(found: true, value: direct);
  }

  final computed = _resolveComputedVariableValue(resolvedKey, updates);
  if (computed != null) {
    return _ResolvedExpression(found: true, value: computed);
  }

  final bracketCollection = _resolveBracketCollectionVariableValue(
    resolvedKey,
    updates,
  );
  if (bracketCollection != null) {
    return bracketCollection;
  }

  if (_looksLikeLiteralFallback(trimmed)) {
    return _ResolvedExpression(found: true, value: resolvedKey);
  }

  return const _ResolvedExpression(found: false);
}

_ResolvedExpression _evaluateExpression(
  String expression,
  Map<String, String> updates,
) {
  final candidates = _splitTopLevel(expression, '|');
  if (candidates.length <= 1) {
    return _evaluateSingleExpression(expression, updates);
  }

  for (final candidate in candidates) {
    final outcome = _evaluateSingleExpression(candidate, updates);
    if (outcome.found && _isMeaningfulResolvedValue(outcome.value)) {
      return outcome;
    }
  }

  return const _ResolvedExpression(found: false);
}

dynamic resolveTemplateExpressionValue(
  String expression,
  Map<String, String> updates,
) {
  final outcome = _evaluateExpression(expression, updates);
  if (!outcome.found) {
    return null;
  }
  return outcome.value;
}

String resolveTemplateExpressionToString(
  String expression,
  Map<String, String> updates,
) {
  return _stringifyResolvedValue(
    resolveTemplateExpressionValue(expression, updates),
  );
}

String resolveTemplatePlaceholders(
  String initial,
  Map<String, String> updates,
) {
  if (initial.isEmpty) {
    return initial;
  }

  final buffer = StringBuffer();
  var index = 0;
  while (index < initial.length) {
    final start = initial.indexOf('((', index);
    if (start == -1) {
      buffer.write(initial.substring(index));
      break;
    }

    buffer.write(initial.substring(index, start));
    var cursor = start + 2;
    var depth = 0;
    String? quote;
    var escaping = false;
    var foundClosing = false;

    while (cursor < initial.length) {
      final char = initial[cursor];

      if (quote != null) {
        if (escaping) {
          escaping = false;
        } else if (char == r'\') {
          escaping = true;
        } else if (char == quote) {
          quote = null;
        }
        cursor++;
        continue;
      }

      if (char == '"' || char == "'") {
        quote = char;
        cursor++;
        continue;
      }

      if (char == '(') {
        depth++;
        cursor++;
        continue;
      }

      if (char == ')') {
        if (depth > 0) {
          depth--;
          cursor++;
          continue;
        }
        if (cursor + 1 < initial.length && initial[cursor + 1] == ')') {
          final expression = initial.substring(start + 2, cursor);
          buffer.write(resolveTemplateExpressionToString(expression, updates));
          index = cursor + 2;
          foundClosing = true;
          break;
        }
      }

      cursor++;
    }

    if (!foundClosing) {
      buffer.write(initial.substring(start));
      break;
    }
  }

  return buffer.toString();
}
