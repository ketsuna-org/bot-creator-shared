import 'package:bot_creator_shared/utils/bdfd_lexer.dart';
import 'package:bot_creator_shared/utils/bdfd_signature_hints.dart';
import 'package:test/test.dart';

void main() {
  final lexer = BdfdLexer();

  BdfdSignatureContext? ctx(String source, int caret) {
    return bdfdSignatureContextAt(source, caret, lexer.tokenize(source));
  }

  group('bdfdSignatureContextAt', () {
    test('returns null when caret is outside brackets', () {
      expect(ctx(r'$description[hello]', 0), isNull);
      expect(ctx(r'hello world', 5), isNull);
    });

    test('returns context for first argument', () {
      //                       0123456789012345
      const source = r'$description[hello]';
      // caret at 13 = right after '['
      final result = ctx(source, 13);
      expect(result, isNotNull);
      expect(result!.functionName, r'$description');
      expect(result.activeIndex, 0);
      expect(result.parameters, isNotEmpty);
      expect(result.parameters.first, 'Message');
    });

    test('tracks argument index by semicolons', () {
      //                       0123456789012345678901
      const source = r'$addField[title;value;yes]';
      // caret at 10 → inside first arg
      final r1 = ctx(source, 10);
      expect(r1!.activeIndex, 0);

      // caret at 16 → after first semicolon → 2nd arg
      final r2 = ctx(source, 16);
      expect(r2!.activeIndex, 1);
      expect(r2.parameters[1], 'Value');

      // caret at 22 → after second semicolon → 3rd arg
      final r3 = ctx(source, 22);
      expect(r3!.activeIndex, 2);
    });

    test('returns null for functions not in hints map', () {
      const source = r'$unknownFunc[test]';
      final result = ctx(source, 13);
      expect(result, isNull);
    });

    test('handles nested functions — innermost wins', () {
      //                       0         1         2         3
      //                       0123456789012345678901234567890123456
      const source = r'$onlyIf[$getUserVar[coins]>10;error]';
      // caret at 20 → inside $getUserVar brackets
      final inner = ctx(source, 20);
      expect(inner, isNotNull);
      expect(inner!.functionName, r'$getUserVar');
      expect(inner.activeIndex, 0);
    });

    test('returns outer context after inner bracket closes', () {
      //                       0         1         2         3
      //                       0123456789012345678901234567890123456
      const source = r'$onlyIf[$getUserVar[coins]>10;error]';
      // caret at 30 → past the semicolon, inside $onlyIf's 4th arg area
      final outer = ctx(source, 30);
      expect(outer, isNotNull);
      expect(outer!.functionName, r'$onlyIf');
      // '>10' is still part of arg index 0 of $onlyIf (before the ';')
      // 'error' is after the ';' → arg index 1
      // $onlyIf has 4 params: value1, operator, value2, errorMessage
      // but BDFD uses single-bracket syntax: the ';' delimits args
      // In the source there's 1 semicolon before caret=30, so activeIndex=1
      // Clamped to max param index (3)
      expect(outer.activeIndex, 1);
    });

    test('clamps activeIndex to last parameter', () {
      // $description has 2 params. If we somehow have semicolons, clamp.
      const source = r'$description[a;b;c]';
      final result = ctx(source, 16);
      expect(result, isNotNull);
      expect(result!.activeIndex, 1); // clamped to 1 (2 params)
    });

    test('handles zero-parameter functions without clamp errors', () {
      const source = r'$jsonclear[]';
      final result = ctx(source, 11);
      expect(result, isNotNull);
      expect(result!.functionName, r'$jsonclear');
      expect(result.parameters, isEmpty);
      expect(result.activeIndex, 0);
    });

    test('returns null for bare functions without brackets', () {
      const source = r'$authorID';
      final result = ctx(source, 5);
      expect(result, isNull);
    });

    test('handles cursor right after open bracket', () {
      const source = r'$setUserVar[';
      final result = ctx(source, 12);
      expect(result, isNotNull);
      expect(result!.functionName, r'$setUserVar');
      expect(result.activeIndex, 0);
      expect(result.parameters.first, 'name');
    });

    test('handles empty source', () {
      expect(ctx('', 0), isNull);
    });

    test('caret at 0 returns null', () {
      expect(ctx(r'$description[hello]', 0), isNull);
    });

    test('for/loop signature is available', () {
      const source = r'$for[';
      final result = ctx(source, 5);
      expect(result, isNotNull);
      expect(result!.functionName, r'$for');
    });
  });
}
