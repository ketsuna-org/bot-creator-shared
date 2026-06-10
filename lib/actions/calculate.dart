import 'dart:math' as math;

/// Performs a mathematical calculation based on [operation] and operands.
///
/// Returns `{'result': '<value>'}` on success, or `{'error': '...', 'result': ''}` on failure.
Future<Map<String, String>> calculateAction({
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    final expression =
        resolve((payload['expression'] ?? '').toString()).trim();
    if (expression.isNotEmpty) {
      final cleaned = expression.replaceAll(' ', '');
      if (cleaned.isEmpty) return {'result': '0'};
      // Use the same recursive-descent math parser as BDFD $calculate.
      final parser = _MathParser(cleaned);
      final result = parser.parse();
      if (result == null) {
        return {'error': 'Invalid math expression: "$expression"', 'result': ''};
      }
      return {'result': _format(result)};
    }

    final operation =
        resolve((payload['operation'] ?? '').toString()).trim().toLowerCase();
    final rawA = resolve((payload['operandA'] ?? '').toString()).trim();
    final rawB = resolve((payload['operandB'] ?? '').toString()).trim();

    if (operation == 'random') {
      // Random integer between operandA (min, default 0) and operandB (max, default 100)
      final min = int.tryParse(rawA) ?? 0;
      final max = int.tryParse(rawB) ?? 100;
      if (max < min) {
        return {
          'error': 'random: max ($max) must be >= min ($min)',
          'result': '',
        };
      }
      final value = min + math.Random().nextInt(max - min + 1);
      return {'result': value.toString()};
    }

    if (operation == 'randomfloat') {
      final min = double.tryParse(rawA) ?? 0.0;
      final max = double.tryParse(rawB) ?? 1.0;
      if (max < min) {
        return {
          'error': 'randomFloat: max ($max) must be >= min ($min)',
          'result': '',
        };
      }
      final value = min + math.Random().nextDouble() * (max - min);
      return {'result': _format(value)};
    }

    final a = double.tryParse(rawA);
    if (a == null) {
      return {'error': 'operandA "$rawA" is not a valid number', 'result': ''};
    }

    // Unary operations
    switch (operation) {
      case 'sqrt':
        if (a < 0) {
          return {'error': 'sqrt: operandA must be >= 0', 'result': ''};
        }
        return {'result': _format(math.sqrt(a))};
      case 'abs':
        return {'result': _format(a.abs())};
      case 'floor':
        return {'result': a.floor().toString()};
      case 'ceil':
        return {'result': a.ceil().toString()};
      case 'round':
        return {'result': a.round().toString()};
      case 'negate':
        return {'result': _format(-a)};
    }

    // Binary operations — need operandB
    final b = double.tryParse(rawB);
    if (b == null) {
      return {
        'error':
            'operandB "$rawB" is not a valid number for operation "$operation"',
        'result': '',
      };
    }

    switch (operation) {
      case 'add':
      case '+':
        return {'result': _format(a + b)};
      case 'subtract':
      case 'sub':
      case '-':
        return {'result': _format(a - b)};
      case 'multiply':
      case 'mul':
      case '*':
        return {'result': _format(a * b)};
      case 'divide':
      case 'div':
      case '/':
        if (b == 0) {
          return {'error': 'Division by zero', 'result': ''};
        }
        return {'result': _format(a / b)};
      case 'modulo':
      case 'mod':
      case '%':
        if (b == 0) {
          return {'error': 'Modulo by zero', 'result': ''};
        }
        return {'result': _format(a % b)};
      case 'power':
      case 'pow':
      case '^':
        return {'result': _format(math.pow(a, b).toDouble())};
      case 'min':
        return {'result': _format(math.min(a, b))};
      case 'max':
        return {'result': _format(math.max(a, b))};
      case 'log':
        if (a <= 0) {
          return {'error': 'log: operandA must be > 0', 'result': ''};
        }
        final base = b > 0 ? b : math.e;
        return {'result': _format(math.log(a) / math.log(base))};
      default:
        return {
          'error':
              'Unknown operation: "$operation". Supported: add, subtract, multiply, divide, modulo, power, sqrt, abs, floor, ceil, round, min, max, log, negate, random, randomFloat',
          'result': '',
        };
    }
  } catch (e) {
    return {'error': 'Calculate error: $e', 'result': ''};
  }
}

/// Formats a double: removes unnecessary trailing zeros.
String _format(double value) {
  if (value.isNaN || value.isInfinite) {
    return value.toString();
  }
  if (value == value.truncateToDouble()) {
    return value.truncate().toString();
  }
  // Limit to reasonable precision
  return double.parse(value.toStringAsFixed(10)).toString();
}

/// Recursive-descent math expression parser.
class _MathParser {
  final String _input;
  int _pos = 0;

  _MathParser(this._input);

  double? parse() {
    final result = _expression();
    if (_pos < _input.length) return null;
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
        _pos++;
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
    final start = _pos;
    if (_pos < _input.length && _input[_pos] == '-') _pos++;
    while (_pos < _input.length && (_isDigit(_input[_pos]) || _input[_pos] == '.')) {
      _pos++;
    }
    if (_pos == start + 1 && _input[start] == '-') return null;
    if (_pos == start) return null;
    return double.tryParse(_input.substring(start, _pos));
  }

  static bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
}
