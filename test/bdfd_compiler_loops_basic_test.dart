import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdCompiler', () {
    test('resolves loop computed variables \$i and \$loopCount', () {
      final result = BdfdCompiler().compile(
        r'$for[3]$reply$i is $loopCount$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].payload['content'], '0 is 1');
      expect(result.actions[1].payload['content'], '1 is 2');
      expect(result.actions[2].payload['content'], '2 is 3');
    });

    test('resolves \$loopIndex as alias for \$i', () {
      final result = BdfdCompiler().compile(
        r'$for[2]$reply$c[]index=$loopIndex$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].payload['content'], 'index=0');
      expect(result.actions[1].payload['content'], 'index=1');
    });

    test('restores loop index after nested loops', () {
      final result = BdfdCompiler().compile(
        r'$for[2]$reply$c[]outer=$i$for[2]$reply$c[]inner=$i$endfor$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(6));
      expect(result.actions[0].payload['content'], 'outer=0');
      expect(result.actions[1].payload['content'], 'inner=0');
      expect(result.actions[2].payload['content'], 'inner=1');
      expect(result.actions[3].payload['content'], 'outer=1');
      expect(result.actions[4].payload['content'], 'inner=0');
      expect(result.actions[5].payload['content'], 'inner=1');
    });

    test('transpiles multiple targeted embeds and supports inserting fields by index', () {
      final result = BdfdCompiler().compile(
        r'$title[First Embed;0]'
        r'$description[This is the first embed;0]'
        r'$title[Second Embed;1]'
        r'$description[This is the second embed;1]'
        r'$addField[A;1;yes]'
        r'$addField[C;3;yes]'
        r'$addField[B;2;yes;1]', // inserts B at index 1
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final payload = result.actions.single.payload;
      expect(payload['embeds'], isList);
      final embeds = payload['embeds'] as List;
      expect(embeds, hasLength(2));

      final first = embeds[0] as Map<String, dynamic>;
      expect(first['title'], 'First Embed');
      expect(first['description'], 'This is the first embed');

      final second = embeds[1] as Map<String, dynamic>;
      expect(second['title'], 'Second Embed');
      expect(second['description'], 'This is the second embed');

      final fields = first['fields'] as List;
      expect(fields, hasLength(3));
      expect(fields[0]['name'], 'A');
      expect(fields[1]['name'], 'B');
      expect(fields[2]['name'], 'C');
    });

    test('inlines response-only loop body into pending embed', () {
      final result = BdfdCompiler().compile(
        r'$title[Test]$for[3]$addField[Item $loopCount;val $i;yes]$endfor$color[#FF0000]$footer[Done]',
      );

      expect(result.hasErrors, isFalse);
      // Should produce a SINGLE respondWithMessage action with all fields.
      expect(result.actions, hasLength(1));
      final payload = result.actions.single.payload;
      expect(payload['embeds'], isList);
      final embeds = payload['embeds'] as List;
      expect(embeds, hasLength(1));
      final embed = embeds[0] as Map<String, dynamic>;
      expect(embed['title'], 'Test');
      expect(embed['color'], '#FF0000');
      expect(embed['footer'], containsPair('text', 'Done'));
      final fields = embed['fields'] as List;
      expect(fields, hasLength(3));
      expect(fields[0]['name'], 'Item 1');
      expect(fields[0]['value'], 'val 0');
      expect(fields[1]['name'], 'Item 2');
      expect(fields[1]['value'], 'val 1');
      expect(fields[2]['name'], 'Item 3');
      expect(fields[2]['value'], 'val 2');
    });

    test('inlines json-mutation loop then reads results in embed', () {
      final result = BdfdCompiler().compile(
        r'$jsonClear$jsonArray[n]$for[5]$jsonArrayAppend[n;$i]$endfor$title[Count: $jsonArrayCount[n]]$description[$jsonJoinArray[n;-]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final embed =
          (result.actions.single.payload['embeds'] as List)[0]
              as Map<String, dynamic>;
      expect(embed['title'], 'Count: 5');
      expect(embed['description'], '0-1-2-3-4');
    });
  });
}
