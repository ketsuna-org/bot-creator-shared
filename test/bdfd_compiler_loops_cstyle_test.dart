import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdCompiler', () {
    test('C-style for loop with single variable', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0; i < 5; i++]$reply$i$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(5));
      expect(result.actions[0].payload['content'], '0');
      expect(result.actions[1].payload['content'], '1');
      expect(result.actions[4].payload['content'], '4');
    });

    test('C-style for loop with two variables', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0, j = 10; i <= 3; i++, j--]$reply$i-$j$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].payload['content'], '0-10');
      expect(result.actions[1].payload['content'], '1-9');
      expect(result.actions[2].payload['content'], '2-8');
      expect(result.actions[3].payload['content'], '3-7');
    });

    test('C-style for loop with += and -= updates', () {
      final result = BdfdCompiler().compile(
        r'$for[x = 0; x < 20; x += 5]$reply$x$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].payload['content'], '0');
      expect(result.actions[1].payload['content'], '5');
      expect(result.actions[2].payload['content'], '10');
      expect(result.actions[3].payload['content'], '15');
    });

    test('C-style for loop with decrement', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 5; i > 0; i--]$reply$i$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(5));
      expect(result.actions[0].payload['content'], '5');
      expect(result.actions[1].payload['content'], '4');
      expect(result.actions[4].payload['content'], '1');
    });

    test('C-style for loop respects max iteration limit', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0; i < 9999; i++]$reply$i$endfor',
      );

      expect(result.hasErrors, isFalse);
      // Capped at 100
      expect(result.actions, hasLength(100));
    });

    test('C-style for loop inlines into embed response', () {
      final result = BdfdCompiler().compile(
        r'$title[Countdown]$for[i = 3; i >= 1; i--]$addField[Step $i;Go;no]$endfor$color[#00FF00]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final embed =
          (result.actions.single.payload['embeds'] as List)[0]
              as Map<String, dynamic>;
      expect(embed['title'], 'Countdown');
      expect(embed['color'], '#00FF00');
      final fields = embed['fields'] as List;
      expect(fields, hasLength(3));
      expect(fields[0]['name'], 'Step 3');
      expect(fields[1]['name'], 'Step 2');
      expect(fields[2]['name'], 'Step 1');
    });

    test('C-style for loop with condition comparing two variables', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0, j = 3; i < j; i++]$reply$i$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].payload['content'], '0');
      expect(result.actions[1].payload['content'], '1');
      expect(result.actions[2].payload['content'], '2');
    });

    test('C-style for loop reports diagnostic for invalid init', () {
      final result = BdfdCompiler().compile(
        r'$for[badstuff; i < 5; i++]$reply$c[]x$endfor',
      );

      expect(result.hasErrors, isTrue);
      expect(result.actions, isEmpty);
    });

    test('nested C-style loop restores variables', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0; i < 2; i++]$reply$c[]outer=$i$for[j = 10; j < 12; j++]$reply$c[]inner=$j$endfor$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(6));
      expect(result.actions[0].payload['content'], 'outer=0');
      expect(result.actions[1].payload['content'], 'inner=10');
      expect(result.actions[2].payload['content'], 'inner=11');
      expect(result.actions[3].payload['content'], 'outer=1');
      expect(result.actions[4].payload['content'], 'inner=10');
      expect(result.actions[5].payload['content'], 'inner=11');
    });
  });
}
