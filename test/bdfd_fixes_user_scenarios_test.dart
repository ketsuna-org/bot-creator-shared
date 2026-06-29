import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:test/test.dart';

/// Tests for the user-reported BDFD function bugs.
/// Each test mirrors the exact code samples from user reports.
void main() {
  group(r'User scenario: $for list iteration', () {
    test(r'$for[item;Alpha;Beta;Gamma;Delta] iterates over static list', () {
      final result = BdfdCompiler().compile(
        r'$nomention'
        r'$for[item;Alpha;Beta;Gamma;Delta]'
        r'$loopCount. $item (index: $loopIndex)'
        r'$endFor',
      );

      expect(result.hasErrors, isFalse);
      // Response-only body is inlined into a single respondWithMessage.
      expect(result.actions, hasLength(1));
      final content = result.actions.single.payload['content'] as String;
      expect(content, contains('1. Alpha (index: 0)'));
      expect(content, contains('2. Beta (index: 1)'));
      expect(content, contains('3. Gamma (index: 2)'));
      expect(content, contains('4. Delta (index: 3)'));
    });

    test(r'$for[color;red;green;blue] works with embed mutations', () {
      final result = BdfdCompiler().compile(
        r'$title[Colors]'
        r'$for[color;red;green;blue]'
        r'$addField[Color $loopCount;$color;yes]'
        r'$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final embeds = result.actions.single.payload['embeds'] as List;
      final fields = embeds[0]['fields'] as List;
      expect(fields, hasLength(3));
      expect(fields[0]['name'], 'Color 1');
      expect(fields[0]['value'], 'red');
      expect(fields[1]['name'], 'Color 2');
      expect(fields[1]['value'], 'green');
      expect(fields[2]['name'], 'Color 3');
      expect(fields[2]['value'], 'blue');
    });

    test(r'$for[item;sword;shield;potion;bow] with 4 values', () {
      final result = BdfdCompiler().compile(
        r'$for[item;sword;shield;potion;bow]'
        r'$loopCount: $item'
        r'$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final content = result.actions.single.payload['content'] as String;
      expect(content, contains('1: sword'));
      expect(content, contains('2: shield'));
      expect(content, contains('3: potion'));
      expect(content, contains('4: bow'));
    });

    test(r'$for with 2 args iterates over single value', () {
      final result = BdfdCompiler().compile(
        r'$for[only;hello]$only$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['content'], 'hello');
    });
  });

  group(r'User scenario: $json[] initializes context', () {
    test(r'$json[] initializes empty JSON context', () {
      final result = BdfdCompiler().compile(
        r'$json[]'
        r'$jsonSet[items;sword,shield,potion,bow]'
        r'$jsonArray[items;,]'
        r'Total: $jsonArrayCount[items]',
      );

      expect(result.hasErrors, isFalse);
      final content = result.actions
          .where((a) => a.payload['content'] != null)
          .map((a) => a.payload['content'].toString())
          .join();
      expect(content, contains('Total: 4'));
    });

    test(r'$json[{"key":"value"}] initializes from JSON literal', () {
      final result = BdfdCompiler().compile(
        r'$json[{"Alice":95,"Bob":78}]'
        r'Alice: $json[Alice] | Bob: $json[Bob]',
      );

      expect(result.hasErrors, isFalse);
      final content = result.actions
          .where((a) => a.payload['content'] != null)
          .map((a) => a.payload['content'].toString())
          .join();
      expect(content, contains('Alice: 95'));
      expect(content, contains('Bob: 78'));
    });
  });

  group(r'User scenario: $jsonKey[] / $jsonValue[] in $jsonForEach', () {
    test(r'$jsonKey[] and $jsonValue[] work inside $jsonForEach', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"x":1,"y":2,"z":3}]'
        r'$jsonForEach[]'
        r'$jsonKey[]=$jsonValue[]'
        r'$endJsonForEach',
      );

      expect(result.hasErrors, isFalse);
      final feAction = result.actions.where(
        (a) => a.type == BotCreatorActionType.jsonForEachLoop,
      );
      expect(feAction, hasLength(1));
    });

    test(r'$jsonValue[] is recognized as inline function', () {
      // Outside jsonForEach, $jsonValue[path] reads from JSON context.
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"a":"hello"}]'
        r'Value: $jsonValue[a]',
      );

      expect(result.hasErrors, isFalse);
      final content = result.actions
          .where((a) => a.payload['content'] != null)
          .map((a) => a.payload['content'].toString())
          .join();
      expect(content, contains('Value: hello'));
    });
  });

  group(r'User scenario: textSplit + JSON array workflow', () {
    test('textSplit and jsonArray work together', () {
      final result = BdfdCompiler().compile(
        r'$textSplit[sword,shield,potion,bow;,]'
        r'$json[]'
        r'$jsonSet[items;sword,shield,potion,bow]'
        r'$jsonArray[items;,]'
        r'Total: $jsonArrayCount[items]'
        r'First: $splitText[1]',
      );

      expect(result.hasErrors, isFalse);
      final content = result.actions
          .where((a) => a.payload['content'] != null)
          .map((a) => a.payload['content'].toString())
          .join();
      expect(content, contains('Total: 4'));
      expect(content, contains('First: sword'));
    });
  });

  group(r'User scenario: no regression on existing $for[n]', () {
    test(r'$for[3] still works as numeric count', () {
      final result = BdfdCompiler().compile(
        r'$for[3]$reply$c[]Line $loopCount$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].payload['content'], 'Line 1');
      expect(result.actions[1].payload['content'], 'Line 2');
      expect(result.actions[2].payload['content'], 'Line 3');
    });
  });
}
