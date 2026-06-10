import 'dart:math' as math;

/// Recursive-descent math expression parser.
///
/// Supports +, -, *, /, %, ^, **, parentheses, and unary minus.
/// Used by BDFD $calculate (compile-time), ((calculate[...])) (runtime),
/// and the Calculate visual action block.
class MathExpressionParser {
  final String _input;
  int _pos = 0;

  MathExpressionParser(this._input);

  /// Returns the evaluated result, or null if the expression is invalid.
  double? parse() {
    final result = _expression();
    if (_pos < _input.length) return null; // trailing garbage
    return result;
  }

  double? _expression() {
    var left = _term();
    if (left == null) return null;

    while (_pos < _input.length) {
      final op = _input[_pos];
      if (op != '+' && op != '-') break;
      _pos++;
      final right = _term();
      if (right == null) return null;
      left = op == '+' ? left! + right : left! - right;
    }
    return left;
  }

  double? _term() {
    var left = _factor();
    if (left == null) return null;

    while (_pos < _input.length) {
      final op = _input[_pos];
      if (op != '*' && op != '/' && op != '%') break;
      _pos++;
      final right = _factor();
      if (right == null) return null;
      if (op == '*') {
        left = left! * right;
      } else if (op == '/') {
        left = right != 0 ? left! / right : 0;
      } else {
        left = right != 0 ? left! % right : 0;
      }
    }
    return left;
  }

  double? _factor() {
    var left = _unary();
    if (left == null) return null;

    while (_pos < _input.length) {
      final ch = _input[_pos];
      if (ch != '^' && ch != '*') break;
      if (ch == '*') {
        if (_pos + 1 >= _input.length || _input[_pos + 1] != '*') break;
        _pos++; // skip second *
      }
      _pos++;
      final right = _unary();
      if (right == null) return null;
      left = math.pow(left!, right).toDouble();
    }
    return left;
  }

  double? _unary() {
    if (_pos >= _input.length) return null;
    if (_input[_pos] == '-') {
      _pos++;
      final value = _unary();
      return value != null ? -value : null;
    }
    if (_input[_pos] == '+') {
      _pos++;
      return _unary();
    }
    return _primary();
  }

  double? _primary() {
    if (_pos >= _input.length) return null;

    if (_input[_pos] == '(') {
      _pos++;
      final result = _expression();
      if (_pos < _input.length && _input[_pos] == ')') {
        _pos++;
        return result;
      }
      return null;
    }

    // Number
    final start = _pos;
    if (_pos < _input.length && _input[_pos] == '-') _pos++;
    while (_pos < _input.length &&
        (_isDigit(_input[_pos]) || _input[_pos] == '.')) {
      _pos++;
    }
    if (_pos == start + 1 && _input[start] == '-') return null; // lone '-'
    if (_pos == start) return null;
    return double.tryParse(_input.substring(start, _pos));
  }

  static bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  /// Convenience: evaluates [expression] and returns the result, or null if invalid.
  static double? evaluate(String expression) {
    final cleaned = expression.replaceAll(' ', '');
    if (cleaned.isEmpty) return null;
    return MathExpressionParser(cleaned).parse();
  }

  /// Formats a numeric result, optionally preserving decimals.
  ///
  /// When [enableDecimals] is false (default), whole-number doubles are
  /// truncated to int (BDFD default behaviour). When true, the full precision
  /// is preserved.
  static dynamic format(num value, {bool enableDecimals = false}) {
    if (enableDecimals) return value;
    if (value is int) return value;
    if (value is double && value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt();
    }
    if (value.isNaN || value.isInfinite) return value.toString();
    return value;
  }
}
