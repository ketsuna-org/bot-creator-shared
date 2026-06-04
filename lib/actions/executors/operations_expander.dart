/// Operation expander for canvas image compositing.
///
/// Resolves high-level constructs (conditions, forEach loops, composition
/// template slots) into a flat list of concrete operations that the
/// [executeRuntimeImageBlock] executor can process directly.
///
/// Follows the architecture principle: enrich the operation map BEFORE it
/// reaches the pixel-level executor, keeping `image_executor.dart` simple.
///
/// ## Operation types handled
///
/// | Enrichment    | Shape                                     | Output       |
/// |---------------|-------------------------------------------|--------------|
/// | `condition`   | Any op + `"condition": "((var))"`         | Skip if falsy |
/// | `forEach`     | `"op": "forEach"` + `"list"` + `"itemTemplate"` | N ops per item |
/// | `composition` | `"composition": "name"` + `"slots": {...}`| Slot-substituted ops |
library;

import 'dart:convert';

/// Expands enriched canvas operations into a flat list of concrete operations.
///
/// The [resolveValue] callback is used to resolve template placeholders (e.g.,
/// `"((myVar))"`) to their runtime values. This is the same callback passed
/// to the image executor.
///
/// The optional [compositions] map provides named composition templates. Each
/// composition is a `List<Map<String, dynamic>>` of operations with
/// `\$slot.name` placeholders that get replaced by the invocation's `slots`.
///
/// Returns a flat list of `Map<String, dynamic>` operations ready for the
/// pixel-level executor. All high-level constructs (conditions, forEach,
/// composition) have been resolved.
List<Map<String, dynamic>> expandCanvasOperations(
  List<dynamic> operations,
  String Function(String input) resolveValue, {
  Map<String, List<Map<String, dynamic>>>? compositions,
}) {
  final flat = <Map<String, dynamic>>[];

  for (final rawOp in operations) {
    if (rawOp is! Map) continue;

    final op = Map<String, dynamic>.from(
      (rawOp).cast<String, dynamic>(),
    );

    final opType = (op['op'] ?? '').toString();

    // Handle condition: skip operation if condition exists and resolves falsy
    if (op.containsKey('condition')) {
      final condition = _resolve(op['condition'], resolveValue);
      if (!_isTruthy(condition)) {
        continue; // Skip this operation entirely
      }
    }

    // Composition reference (uses 'composition' key, not 'op')
    if (op.containsKey('composition')) {
      flat.addAll(
          _expandComposition(op, resolveValue, compositions: compositions));
      continue;
    }

    switch (opType) {
      case 'forEach':
        flat.addAll(
            _expandForEach(op, resolveValue, compositions: compositions));
        break;
      default:
        // Concrete operation — pass through after resolving all values
        flat.add(_resolveOperationValues(op, resolveValue));
    }
  }

  return flat;
}

/// Resolves a template value string.
///
/// Template placeholders containing `((` are resolved via [resolveValue].
/// Non-template strings are returned as-is.
String _resolve(dynamic raw, String Function(String) resolveValue) {
  if (raw == null) return '';
  final s = raw.toString().trim();
  if (s.contains('((')) return resolveValue(s);
  return s;
}

/// Determines if a resolved condition value is truthy.
///
/// Truthy values: non-empty, not "false", not "0", not "null", not "no".
bool _isTruthy(String value) {
  if (value.isEmpty) return false;
  final lower = value.toLowerCase().trim();
  if (lower == 'false' || lower == '0' || lower == 'null' || lower == 'no') {
    return false;
  }
  return true;
}

/// Resolves all string values in an operation through [resolveValue].
///
/// This ensures template placeholders like `"((author.avatar))"` are resolved
/// before the pixel-level executor processes the operation.
Map<String, dynamic> _resolveOperationValues(
  Map<String, dynamic> op,
  String Function(String) resolveValue,
) {
  final resolved = <String, dynamic>{};
  for (final entry in op.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value is String && value.contains('((')) {
      resolved[key] = resolveValue(value);
    } else if (value is Map) {
      resolved[key] = _resolveOperationValues(
        Map<String, dynamic>.from(value.cast<String, dynamic>()),
        resolveValue,
      );
    } else {
      resolved[key] = value;
    }
  }
  return resolved;
}

/// Expands a `forEach` loop into N concrete operations.
///
/// Expected shape:
/// ```json
/// {
///   "op": "forEach",
///   "list": "((leaderboard.entries))",
///   "itemTemplate": {
///     "op": "drawText",
///     "text": "((item.rank)). ((item.name))",
///     "x": "10",
///     "y": "((item.index * 24 + 100))",
///     "fontSize": "14",
///     "color": "white"
///   }
/// }
/// ```
///
/// The `item.index` and `item.<field>` placeholders are scoped to the
/// iteration. Each iteration produces one concrete operation with
/// placeholders resolved to the current item's values.
List<Map<String, dynamic>> _expandForEach(
  Map<String, dynamic> op,
  String Function(String) resolveValue, {
  Map<String, List<Map<String, dynamic>>>? compositions,
}) {
  final listRaw = _resolve(op['list'], resolveValue);
  final template = op['itemTemplate'];
  if (template is! Map || listRaw.isEmpty) return [];

  // Parse the list: expect JSON array string, e.g., '[{"rank":1,"name":"Alice"},...]'
  List items;
  try {
    final decoded = jsonDecode(listRaw);
    items = decoded is List ? decoded : <dynamic>[];
  } catch (_) {
    // Not valid JSON — try comma-separated
    items = listRaw.split(',').where((s) => s.trim().isNotEmpty).toList();
  }

  final result = <Map<String, dynamic>>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];

    // Build a scoped resolver for this iteration.
    // `((item.index))` → the loop index
    // `((item.<field>))` → the item's field (if item is a Map)
    String scopedResolve(String input) {
      var resolved = input;

      // Strategy: match complete ((...)) placeholders containing item. references,
      // resolve them inline, and strip the ((...)) wrapper.
      resolved = resolved.replaceAllMapped(
        RegExp(r'\(\(([^)]*item\.[^)]*)\)\)'),
        (match) {
          var content = match.group(1)!;

          // Replace item.index → numeric index
          content = content.replaceAll('item.index', i.toString());
          content = content.replaceAll('item.i', i.toString());

          // Replace item.<field> → field values from Map items
          if (item is Map<String, dynamic>) {
            content = content.replaceAllMapped(
              RegExp(r'item\.(\w+)'),
              (fm) {
                final field = fm.group(1)!;
                if (field == 'index' || field == 'i') return i.toString();
                final value = item[field];
                return value?.toString() ?? fm.group(0)!;
              },
            );
          }

          // If the result is a numeric/arithmetic expression, evaluate it.
          // Otherwise, it's a plain string value — return as-is (no ((...))).
          if (content.contains('item.')) {
            return match.group(0)!; // Still has unresolved refs
          }

          final trimmed = content.trim();
          if (RegExp(r'^[\d\s.+\-*/]+$').hasMatch(trimmed)) {
            try {
              final result = _evalSimpleArith(trimmed);
              if (result == result.roundToDouble() && result.isFinite) {
                return result.toInt().toString();
              }
              return result.toString();
            } catch (_) {}
          }

          // Plain string value — return directly, stripping ((...)) wrapper
          return content;
        },
      );

      // Also handle ((item)) for string list items
      resolved = resolved.replaceAll('((item))', item.toString());

      return resolved;
    }

    final concrete = _resolveOperationValues(
      Map<String, dynamic>.from(template.cast<String, dynamic>()),
      scopedResolve,
    );

    // Recursively expand if the template itself is a forEach or composition
    final opType = (template['op'] ?? '').toString();
    if (opType == 'forEach') {
      result.addAll(
          _expandForEach(concrete, scopedResolve, compositions: compositions));
    } else if (opType == 'composition') {
      result.addAll(_expandComposition(
          concrete, scopedResolve, compositions: compositions));
    } else {
      result.add(concrete);
    }
  }

  return result;
}

/// Expands a `composition` reference into its concrete operations.
///
/// Expected shape:
/// ```json
/// {
///   "composition": "welcomeCard",
///   "slots": {
///     "avatar": "((author.avatar))",
///     "username": "((author.name))",
///     "memberCount": "((guild.memberCount))"
///   }
/// }
/// ```
///
/// Compositions are defined in the bot's configuration as named operation
/// lists. Each composition uses `\$slot.name` placeholders that get replaced
/// by the invocation's `slots` values.
List<Map<String, dynamic>> _expandComposition(
  Map<String, dynamic> op,
  String Function(String) resolveValue, {
  Map<String, List<Map<String, dynamic>>>? compositions,
}) {
  final compositionName = _resolve(op['composition'], resolveValue);
  final slotsRaw = op['slots'];
  final Map<String, String> slots;

  if (slotsRaw is Map) {
    slots = <String, String>{};
    for (final entry in slotsRaw.entries) {
      slots[entry.key.toString()] =
          _resolve(entry.value, resolveValue);
    }
  } else {
    slots = const {};
  }

  // Look up the composition template
  final templateOps = compositions?[compositionName];
  if (templateOps == null || templateOps.isEmpty) {
    // Composition not found — return empty (no-op)
    return [];
  }

  // Build a scoped resolver that substitutes \$slot.name with actual values
  String scopedResolve(String input) {
    var resolved = input;
    for (final entry in slots.entries) {
      resolved = resolved.replaceAll('\$slot.${entry.key}', entry.value);
    }
    // Resolve remaining placeholders via main resolver
    if (resolved.contains('((')) {
      resolved = resolveValue(resolved);
    }
    return resolved;
  }

  // Deep-copy template ops and resolve slot values.
  // Apply slot substitution BEFORE _resolveOperationValues since it only
  // triggers on ((...)) patterns, not $slot.* placeholders.
  final result = <Map<String, dynamic>>[];
  for (final templateOp in templateOps) {
    // Pre-substitute $slot.* placeholders in all string values
    final preSubbed = <String, dynamic>{};
    for (final entry in templateOp.entries) {
      final value = entry.value;
      if (value is String) {
        var s = value;
        for (final slot in slots.entries) {
          s = s.replaceAll('\$slot.${slot.key}', slot.value);
        }
        preSubbed[entry.key] = s;
      } else {
        preSubbed[entry.key] = value;
      }
    }

    final resolved = _resolveOperationValues(
      preSubbed,
      scopedResolve,
    );

    // Recursively expand nested forEach/composition
    final opType = (resolved['op'] ?? '').toString();
    if (opType == 'forEach') {
      result.addAll(
          _expandForEach(resolved, scopedResolve, compositions: compositions));
    } else if (opType == 'composition') {
      result.addAll(_expandComposition(
          resolved, scopedResolve, compositions: compositions));
    } else {
      result.add(resolved);
    }
  }

  return result;
}

/// Evaluates a simple arithmetic expression string.
///
/// Supports +, -, *, / with integer operands. Does NOT support parentheses
/// or operator precedence — evaluates left-to-right for simplicity and safety.
///
/// This is intentionally limited: it only handles the straightforward
/// expressions that a forEach template would produce (e.g.,
/// `"0 * 24 + 50"` after field substitution).
///
/// Throws [FormatException] if the expression cannot be parsed.
double _evalSimpleArith(String expr) {
  final trimmed = expr.trim();
  if (trimmed.isEmpty) throw const FormatException('Empty expression');

  // Try simple number first
  final single = double.tryParse(trimmed);
  if (single != null) return single;

  // Split into tokens: numbers and operators
  final tokens = <String>[];
  final buffer = StringBuffer();
  for (var i = 0; i < trimmed.length; i++) {
    final ch = trimmed[i];
    if (ch == ' ') {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
      continue;
    }
    if (ch == '+' || ch == '-' || ch == '*' || ch == '/') {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
      tokens.add(ch);
    } else if (ch == '.' || (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57)) {
      buffer.write(ch);
    } else {
      throw FormatException('Unexpected character: $ch');
    }
  }
  if (buffer.isNotEmpty) tokens.add(buffer.toString());

  if (tokens.isEmpty) throw const FormatException('Empty expression');
  if (tokens.length == 1) return double.parse(tokens[0]);

  // Evaluate left-to-right: result op next, ignoring precedence for simplicity.
  // The templates produce simple expressions like "0 * 24 + 50".
  var result = double.parse(tokens[0]);
  for (var i = 1; i < tokens.length; i += 2) {
    if (i + 1 >= tokens.length) break;
    final op = tokens[i];
    final operand = double.parse(tokens[i + 1]);
    switch (op) {
      case '+': result += operand; break;
      case '-': result -= operand; break;
      case '*': result *= operand; break;
      case '/': result /= operand; break;
      default: throw FormatException('Unknown operator: $op');
    }
  }

  return result;
}
