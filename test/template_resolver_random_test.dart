import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('random template functions', () {
    test('coin() returns "true" or empty string', () {
      final results = <String>{};
      // Run multiple times to cover both outcomes.
      for (var i = 0; i < 200; i++) {
        results.add(resolveTemplatePlaceholders('((coin()))', {}));
      }
      expect(results, containsAll(['true', '']));
      // No other values should appear.
      expect(results.difference({'true', ''}), isEmpty);
    });

    test('random() returns "true" or empty string (legacy alias)', () {
      final results = <String>{};
      for (var i = 0; i < 200; i++) {
        results.add(resolveTemplatePlaceholders('((random()))', {}));
      }
      expect(results, containsAll(['true', '']));
    });

    test('randomchoice picks from provided arguments', () {
      final results = <String>{};
      for (var i = 0; i < 200; i++) {
        results.add(
          resolveTemplatePlaceholders('((randomchoice("a", "b", "c")))', {}),
        );
      }
      expect(results, containsAll(['a', 'b', 'c']));
      expect(results.difference({'a', 'b', 'c'}), isEmpty);
    });

    test('randomint returns integer in range', () {
      final results = <int>{};
      for (var i = 0; i < 200; i++) {
        final s = resolveTemplatePlaceholders('((randomint(1, 3)))', {});
        results.add(int.parse(s));
      }
      expect(results, containsAll([1, 2, 3]));
      expect(results.every((v) => v >= 1 && v <= 3), isTrue);
    });

    test('randomchoice with no args returns empty', () {
      final resolved = resolveTemplatePlaceholders('((randomchoice()))', {});
      expect(resolved, '');
    });

    test('randomint with invalid range returns empty', () {
      final resolved = resolveTemplatePlaceholders('((randomint(5, 2)))', {});
      expect(resolved, '');
    });
  });
}
