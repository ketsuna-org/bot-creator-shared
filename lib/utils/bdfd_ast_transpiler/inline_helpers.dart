part of '../bdfd_ast_transpiler.dart';

extension _BdfdAstTranspilationScopeInlineHelpers
    on _BdfdAstTranspilationScope {
  String _inlineReplaceText(BdfdFunctionCallAst node) {
    final text = _stringifyArgument(node, 0);
    final sample = _stringifyArgument(node, 1);
    final replacement = _stringifyArgument(node, 2);
    final amountRaw = _stringifyArgument(node, 3).trim();
    final amount = int.tryParse(amountRaw) ?? 1;

    if (sample.isEmpty) {
      return text;
    }

    if (amount == -1) {
      return text.replaceAll(sample, replacement);
    }

    var result = text;
    var count = 0;
    while (count < amount) {
      final index = result.indexOf(sample);
      if (index < 0) {
        break;
      }
      result =
          result.substring(0, index) +
          replacement +
          result.substring(index + sample.length);
      count++;
    }
    return result;
  }

  String _inlineTitleCase(String text) {
    if (text.isEmpty) {
      return '';
    }
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) {
            return word;
          }
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _inlineCropText(BdfdFunctionCallAst node) {
    final text = _stringifyArgument(node, 0);
    final lengthRaw = _stringifyArgument(node, 1).trim();
    final suffix = _stringifyArgument(node, 2);
    final length = int.tryParse(lengthRaw) ?? text.length;
    if (length >= text.length) {
      return text;
    }
    return text.substring(0, length) + suffix;
  }

  String _inlineRepeatMessage(BdfdFunctionCallAst node) {
    final text = _stringifyArgument(node, 0);
    final countRaw = _stringifyArgument(node, 1).trim();
    final count = int.tryParse(countRaw) ?? 1;
    if (count <= 0) {
      return '';
    }
    if (count > 100) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} repeat count capped at 100.',
          severity: BdfdTranspileDiagnosticSeverity.warning,
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return text * 100;
    }
    return text * count;
  }

  String _inlineRemoveContains(BdfdFunctionCallAst node) {
    var text = _stringifyArgument(node, 0);
    for (var i = 1; i < node.arguments.length; i++) {
      final target = _stringifyArgument(node, i);
      if (target.isNotEmpty) {
        text = text.replaceAll(target, '');
      }
    }
    return text;
  }

  String _inlineNumberSeparator(BdfdFunctionCallAst node) {
    final numberRaw = _stringifyArgument(node, 0).trim();
    final separator = _stringifyArgument(node, 1);
    final sep = separator.isEmpty ? ',' : separator;
    final parts = numberRaw.split('.');
    final intPart = parts[0];

    final buffer = StringBuffer();
    var count = 0;
    for (var i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0 && intPart[i] != '-') {
        buffer.write(sep);
      }
      buffer.write(intPart[i]);
      count++;
    }

    final result = buffer.toString().split('').reversed.join();
    if (parts.length > 1) {
      return '$result.${parts[1]}';
    }
    return result;
  }

  void _textSplitState(BdfdFunctionCallAst node) {
    final text = _stringifyArgument(node, 0);
    final separator = _stringifyArgument(node, 1);
    _textSplitParts = text.split(separator);
  }

  String _inlineSplitText(BdfdFunctionCallAst node) {
    final indexRaw = _stringifyArgument(node, 0).trim();
    final index = int.tryParse(indexRaw);
    if (index == null || index < 1 || index > _textSplitParts.length) {
      return '';
    }
    return _textSplitParts[index - 1];
  }

  String _inlineEditSplitText(BdfdFunctionCallAst node) {
    final indexRaw = _stringifyArgument(node, 0).trim();
    final value = _stringifyArgument(node, 1);
    final index = int.tryParse(indexRaw);
    if (index == null || index < 1 || index > _textSplitParts.length) {
      return '';
    }
    _textSplitParts[index - 1] = value;
    return '';
  }

  String _inlineGetTextSplitIndex(BdfdFunctionCallAst node) {
    final value = _stringifyArgument(node, 0);
    final index = _textSplitParts.indexOf(value);
    return index >= 0 ? (index + 1).toString() : '-1';
  }

  String _inlineJoinSplitText(BdfdFunctionCallAst node) {
    final separator = _stringifyArgument(node, 0);
    return _textSplitParts.join(separator);
  }

  String _inlineRemoveSplitTextElement(BdfdFunctionCallAst node) {
    final indexRaw = _stringifyArgument(node, 0).trim();
    final index = int.tryParse(indexRaw);
    if (index != null && index >= 1 && index <= _textSplitParts.length) {
      _textSplitParts.removeAt(index - 1);
    }
    return '';
  }

  // ── Math inline helpers ──────────────────────────────────────

  String _inlineCalculate(BdfdFunctionCallAst node) {
    final expression = _stringifyArgument(node, 0).trim();
    if (expression.isEmpty) {
      return '0';
    }
    final result = _evaluateSimpleMathExpression(expression);
    if (result == null) {
      return '((calculate[$expression]))';
    }
    if (result == result.roundToDouble() && result.abs() < 1e15) {
      return result.toInt().toString();
    }
    return result.toString();
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

    final twoOperandPattern = RegExp(
      r'^(-?[\d.]+)\s*([+\-*/%^])\s*(-?[\d.]+)$',
    );
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
        return math.pow(left, right).toDouble();
      default:
        return null;
    }
  }

  String _inlineMathUnary(
    BdfdFunctionCallAst node,
    int Function(double) operation,
  ) {
    final raw = _stringifyArgument(node, 0).trim();
    final value = double.tryParse(raw);
    if (value == null) {
      return '((${node.normalizedName}[$raw]))';
    }
    return operation(value).toString();
  }

  String _inlineMathUnaryDouble(
    BdfdFunctionCallAst node,
    double Function(double) operation,
  ) {
    final raw = _stringifyArgument(node, 0).trim();
    final value = double.tryParse(raw);
    if (value == null) {
      return '((${node.normalizedName}[$raw]))';
    }
    final result = operation(value);
    if (result == result.roundToDouble() && result.abs() < 1e15) {
      return result.toInt().toString();
    }
    return result.toString();
  }

  String _inlineMathBinary(
    BdfdFunctionCallAst node,
    num Function(num, num) operation,
  ) {
    final aRaw = _stringifyArgument(node, 0).trim();
    final bRaw = _stringifyArgument(node, 1).trim();
    final a = num.tryParse(aRaw);
    final b = num.tryParse(bRaw);
    if (a == null || b == null) {
      return '((${node.normalizedName}[$aRaw;$bRaw]))';
    }
    final result = operation(a, b);
    if (result is double &&
        result == result.roundToDouble() &&
        result.abs() < 1e15) {
      return result.toInt().toString();
    }
    return result.toString();
  }

  String _inlineMathBinaryOp(
    BdfdFunctionCallAst node,
    num Function(num, num) operation,
  ) {
    final aRaw = _stringifyArgument(node, 0).trim();
    final bRaw = _stringifyArgument(node, 1).trim();
    final a = num.tryParse(aRaw);
    final b = num.tryParse(bRaw);
    if (a == null || b == null) {
      return '((${node.normalizedName}[$aRaw;$bRaw]))';
    }
    final result = operation(a, b);
    if (result is double &&
        result == result.roundToDouble() &&
        result.abs() < 1e15) {
      return result.toInt().toString();
    }
    return result.toString();
  }

  String _inlineSum(BdfdFunctionCallAst node) {
    num total = 0;
    for (var i = 0; i < node.arguments.length; i++) {
      final raw = _stringifyArgument(node, i).trim();
      final value = num.tryParse(raw);
      if (value == null) {
        final args = List.generate(
          node.arguments.length,
          (j) => _stringifyArgument(node, j).trim(),
        ).join(';');
        return '((sum[$args]))';
      }
      total += value;
    }
    if (total is double &&
        total == total.roundToDouble() &&
        total.abs() < 1e15) {
      return total.toInt().toString();
    }
    return total.toString();
  }

  String _inlineSort(BdfdFunctionCallAst node) {
    final values = <String>[];
    for (var i = 0; i < node.arguments.length; i++) {
      final raw = _stringifyArgument(node, i).trim();
      if (raw.isNotEmpty) {
        values.add(raw);
      }
    }
    final allNumeric = values.every((v) => num.tryParse(v) != null);
    if (allNumeric) {
      values.sort((a, b) => num.parse(a).compareTo(num.parse(b)));
    } else {
      values.sort();
    }
    return values.join(';');
  }

  // ── Boolean check helpers ──────────────────────────────────────

  String _inlineIsBoolean(BdfdFunctionCallAst node) {
    final raw = _stringifyArgument(node, 0).trim().toLowerCase();
    const booleans = {'true', 'false', 'yes', 'no', '1', '0', 'on', 'off'};
    return booleans.contains(raw) ? 'true' : 'false';
  }

  String _inlineIsInteger(BdfdFunctionCallAst node) {
    final raw = _stringifyArgument(node, 0).trim();
    return int.tryParse(raw) != null ? 'true' : 'false';
  }

  String _inlineIsNumber(BdfdFunctionCallAst node) {
    final raw = _stringifyArgument(node, 0).trim();
    return num.tryParse(raw) != null ? 'true' : 'false';
  }

  String _inlineIsValidHex(BdfdFunctionCallAst node) {
    final raw = _stringifyArgument(node, 0).trim();
    final cleaned = raw.startsWith('#') ? raw.substring(1) : raw;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleaned) ? 'true' : 'false';
  }

  String _inlineCheckCondition(BdfdFunctionCallAst node) {
    final expression = _stringifyArgument(node, 0).trim();
    if (expression.isEmpty) {
      return 'false';
    }
    final condition = _parseSimpleCondition(expression);
    return _evaluateConditionStatically(condition) ? 'true' : 'false';
  }

  bool _evaluateConditionStatically(_ParsedCondition condition) {
    switch (condition.operator) {
      case 'equals':
        return condition.left == condition.right;
      case 'notEquals':
        return condition.left != condition.right;
      case 'contains':
        return condition.left.contains(condition.right);
      case 'notContains':
        return !condition.left.contains(condition.right);
      case 'startsWith':
        return condition.left.startsWith(condition.right);
      case 'endsWith':
        return condition.left.endsWith(condition.right);
      case 'isNotEmpty':
        return condition.left.isNotEmpty;
      default:
        final leftNum = num.tryParse(condition.left);
        final rightNum = num.tryParse(condition.right);
        if (leftNum != null && rightNum != null) {
          switch (condition.operator) {
            case 'greaterThan':
              return leftNum > rightNum;
            case 'lessThan':
              return leftNum < rightNum;
            case 'greaterOrEqual':
              return leftNum >= rightNum;
            case 'lessOrEqual':
              return leftNum <= rightNum;
          }
        }
        return false;
    }
  }

  String _inlineCheckContains(BdfdFunctionCallAst node) {
    final text = _stringifyArgument(node, 0);
    for (var i = 1; i < node.arguments.length; i++) {
      final target = _stringifyArgument(node, i);
      if (target.isNotEmpty && text.contains(target)) {
        return 'true';
      }
    }
    return 'false';
  }

  // ── Random helpers ──────────────────────────────────────────

  String _inlineRandom(BdfdFunctionCallAst node) {
    final args = List.generate(
      node.arguments.length,
      (i) => _stringifyArgument(node, i),
    ).join(';');
    return '((random[$args]))';
  }

  String _inlineRandomString(BdfdFunctionCallAst node) {
    final lengthRaw = _stringifyArgument(node, 0).trim();
    final chars = _stringifyArgument(node, 1);
    final length = int.tryParse(lengthRaw) ?? 10;
    final effectiveLength = length.clamp(1, 1000);
    const defaultChars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final charSet = chars.isEmpty ? defaultChars : chars;
    final random = math.Random();
    final buffer = StringBuffer();
    for (var i = 0; i < effectiveLength; i++) {
      buffer.write(charSet[random.nextInt(charSet.length)]);
    }
    return buffer.toString();
  }

  String _inlineRandomText(BdfdFunctionCallAst node) {
    final args = List.generate(
      node.arguments.length,
      (i) => _stringifyArgument(node, i),
    ).join(';');
    return '((randomtext[$args]))';
  }


  // ── getMessage helper ──────────────────────────────────────

  String _inlineGetMessage(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    final property = _stringifyArgument(node, 2).trim();
    if (channelId.isEmpty || messageId.isEmpty) {
      return '((message.content))';
    }
    if (property.isNotEmpty) {
      return '((getMessage[$channelId;$messageId].$property))';
    }
    return '((getMessage[$channelId;$messageId].content))';
  }
}
