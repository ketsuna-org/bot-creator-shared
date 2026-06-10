import 'package:bot_creator_shared/utils/math_parser.dart';
import 'package:test/test.dart';

void main() {
  group('MathExpressionParser', () {
    group('basic operations', () {
      test('addition', () {
        expect(MathExpressionParser.evaluate('2 + 3'), equals(5.0));
      });

      test('subtraction', () {
        expect(MathExpressionParser.evaluate('10 - 3'), equals(7.0));
      });

      test('multiplication', () {
        expect(MathExpressionParser.evaluate('4 * 5'), equals(20.0));
      });

      test('division', () {
        expect(MathExpressionParser.evaluate('10 / 2'), equals(5.0));
      });

      test('modulo', () {
        expect(MathExpressionParser.evaluate('10 % 3'), equals(1.0));
      });

      test('power with ^', () {
        expect(MathExpressionParser.evaluate('2 ^ 3'), equals(8.0));
      });

      test('power with **', () {
        expect(MathExpressionParser.evaluate('2 ** 3'), equals(8.0));
      });
    });

    group('chained operations', () {
      test('addition and subtraction', () {
        expect(MathExpressionParser.evaluate('10 + 5 - 3'), equals(12.0));
      });

      test('multiplication and division', () {
        expect(MathExpressionParser.evaluate('10 * 2 / 4'), equals(5.0));
      });

      test('mixed precedence', () {
        expect(MathExpressionParser.evaluate('2 + 3 * 4'), equals(14.0));
      });

      test('parentheses override precedence', () {
        expect(MathExpressionParser.evaluate('(2 + 3) * 4'), equals(20.0));
      });
    });

    group('decimals', () {
      test('decimal addition', () {
        expect(MathExpressionParser.evaluate('1.5 + 2.5'), equals(4.0));
      });

      test('BDFD example: 10+5.9-9', () {
        expect(MathExpressionParser.evaluate('10+5.9-9'), closeTo(6.9, 0.001));
      });
    });

    group('unary minus', () {
      test('simple negation', () {
        expect(MathExpressionParser.evaluate('-5'), equals(-5.0));
      });

      test('negation in expression', () {
        expect(MathExpressionParser.evaluate('10 + -3'), equals(7.0));
      });

      test('double negation', () {
        expect(MathExpressionParser.evaluate('--5'), equals(5.0));
      });
    });

    group('parentheses', () {
      test('nested parentheses', () {
        expect(MathExpressionParser.evaluate('((2 + 3) * 2)'), equals(10.0));
      });

      test('complex parenthesized', () {
        expect(MathExpressionParser.evaluate('(10 - 3) * (2 + 1)'), equals(21.0));
      });
    });

    group('invalid expressions', () {
      test('empty string', () {
        expect(MathExpressionParser.evaluate(''), isNull);
      });

      test('trailing operator', () {
        expect(MathExpressionParser.evaluate('1+'), isNull);
      });

      test('unknown characters', () {
        expect(MathExpressionParser.evaluate('1 + abc'), isNull);
      });

      test('multiple dots', () {
        expect(MathExpressionParser.evaluate('1.2.3'), isNull);
      });

      test('unmatched parenthesis', () {
        expect(MathExpressionParser.evaluate('(1 + 2'), isNull);
      });

      test('lone minus', () {
        expect(MathExpressionParser.evaluate('-'), isNull);
      });
    });

    group('format', () {
      test('integer stays int', () {
        expect(MathExpressionParser.format(5), equals(5));
      });

      test('whole double truncated to int', () {
        final result = MathExpressionParser.format(6.0);
        expect(result, equals(6));
        expect(result is int, isTrue);
      });

      test('decimal preserved when enableDecimals', () {
        final result = MathExpressionParser.format(6.9, enableDecimals: true);
        expect(result, equals(6.9));
      });

      test('NaN returns string', () {
        expect(MathExpressionParser.format(double.nan), isA<String>());
      });

      test('infinity returns string', () {
        expect(MathExpressionParser.format(double.infinity), isA<String>());
      });
    });
  });
}
