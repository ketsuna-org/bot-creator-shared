import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:test/test.dart';

import 'helpers/variables_test_helpers.dart';

/// Tests for the user-defined function system:
/// $func[name;params...]...$funcEnd + $funcArg[] + $funcReturn[] + $funcCall[]
void main() {
  group(r'Compile-time: $func definition and $funcCall expansion', () {
    test(r'$funcCall returns $funcReturn value', () {
      final result = BdfdCompiler().compile(
        r'$func[greet;name]'
        r'$funcReturn[Hello $funcArg[name]!]'
        r'$funcEnd'
        r'$reply$c[]$funcCall[greet;World]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['content'], 'Hello World!');
    });

    test(r'$funcCall with multiple parameters', () {
      final result = BdfdCompiler().compile(
        r'$func[add;a;b]'
        r'$funcReturn[$funcArg[a] + $funcArg[b]]'
        r'$funcEnd'
        r'$reply$c[]Result: $funcCall[add;10;20]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['content'], 'Result: 10 + 20');
    });

    test(r'$funcCall without $funcReturn uses body text', () {
      final result = BdfdCompiler().compile(
        r'$func[wave;who]'
        r'Waving at $funcArg[who]...'
        r'$funcEnd'
        r'$reply$c[]$funcCall[wave;Alice]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['content'], 'Waving at Alice...');
    });

    test(r'$funcCall called multiple times with different args', () {
      final result = BdfdCompiler().compile(
        r'$func[tag;val]'
        r'$funcReturn[<$funcArg[val]>]'
        r'$funcEnd'
        r'$reply$c[]$funcCall[tag;a] $funcCall[tag;b] $funcCall[tag;c]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['content'], '<a> <b> <c>');
    });

    test(r'$funcCall with runtime placeholder args', () {
      final result = BdfdCompiler().compile(
        r'$func[say;msg]'
        r'$funcReturn[You said: $funcArg[msg]]'
        r'$funcEnd'
        r'$reply$c[]$funcCall[say;$username]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['content'], 'You said: ((user.username))');
    });

    test(r'$funcCall with nested inline functions in args', () {
      final result = BdfdCompiler().compile(
        r'$func[double;x]'
        r'$funcReturn[$calculate[$funcArg[x]*2]]'
        r'$funcEnd'
        r'$reply$c[]$funcCall[double;21]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['content'], '42');
    });

    test(r'$funcCall to undefined function produces diagnostic', () {
      final result = BdfdCompiler().compile(
        r'$reply$c[]$funcCall[nonexistent;1;2]',
      );

      expect(result.hasErrors, isTrue);
    });

    test(r'$func without $funcEnd produces diagnostic', () {
      final result = BdfdCompiler().compile(
        r'$func[broken;a]'
        r'$funcReturn[$funcArg[a]]'
        r'$reply$c[]test',
      );

      expect(result.hasErrors, isTrue);
    });

    test(r'multiple function definitions coexist', () {
      final result = BdfdCompiler().compile(
        r'$func[inc;x]'
        r'$funcReturn[$calculate[$funcArg[x]+1]]'
        r'$funcEnd'
        r'$func[dec;x]'
        r'$funcReturn[$calculate[$funcArg[x]-1]]'
        r'$funcEnd'
        r'$reply$c[]inc: $funcCall[inc;5] dec: $funcCall[dec;5]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['content'], 'inc: 6 dec: 4');
    });

    test(r'$funcCall nested (function calling another function)', () {
      final result = BdfdCompiler().compile(
        r'$func[double;x]'
        r'$funcReturn[$calculate[$funcArg[x]*2]]'
        r'$funcEnd'
        r'$func[quad;x]'
        r'$funcReturn[$funcCall[double;$funcCall[double;$funcArg[x]]]]'
        r'$funcEnd'
        r'$reply$c[]$funcCall[quad;5]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      // quad(5) = double(double(5)) = double(10) = 20
      expect(result.actions[0].payload['content'], '20');
    });

    test(r'$funcCall with fewer args than params fills empty', () {
      final result = BdfdCompiler().compile(
        r'$func[test;a;b;c]'
        r'$funcReturn[$funcArg[a]-$funcArg[b]-$funcArg[c]]'
        r'$funcEnd'
        r'$reply$c[]$funcCall[test;only_one]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['content'], 'only_one--');
    });

    test(r'$funcCall with more args than params ignores extras', () {
      final result = BdfdCompiler().compile(
        r'$func[test;a]'
        r'$funcReturn[$funcArg[a]]'
        r'$funcEnd'
        r'$reply$c[]$funcCall[test;first;second;third]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['content'], 'first');
    });
  });

  group(r'Runtime: $func end-to-end', () {
    Future<(Map<String, String>, List<String>)> runScript(
      String script, {
      Map<String, String> vars = const <String, String>{},
    }) async {
      final compiled = BdfdCompiler().compile(script);
      expect(
        compiled.hasErrors,
        isFalse,
        reason: 'Compile errors: ${compiled.diagnostics.map((d) => d.message).join("; ")}',
      );
      final store = MemoryBotDataStore();
      final variables = <String, String>{
        'guild.id': 'guild-1',
        'bot.id': 'bot-1',
        ...vars,
      };
      final replies = <String>[];
      await executeCompiledActions(
        actions: compiled.actions,
        store: store,
        variables: variables,
        replies: replies,
      );
      return (variables, replies);
    }

    test(r'$funcCall returns value at runtime', () async {
      final (_, replies) = await runScript(
        r'$func[greet;name]'
        r'$funcReturn[Hello $funcArg[name]!]'
        r'$funcEnd'
        r'$reply$c[]$funcCall[greet;World]',
      );

      expect(replies, hasLength(1));
      expect(replies[0], 'Hello World!');
    });

    test(r'$funcCall with runtime variable as arg', () async {
      final (_, replies) = await runScript(
        r'$func[say;msg]'
        r'$funcReturn[Echo: $funcArg[msg]]'
        r'$funcEnd'
        r'$reply$c[]$funcCall[say;$username]',
        vars: <String, String>{'user.username': 'TestUser'},
      );

      expect(replies, hasLength(1));
      // The placeholder ((user.username)) is resolved at runtime.
      expect(replies[0], 'Echo: TestUser');
    });

    test(r'function with math produces correct result at runtime', () async {
      final (_, replies) = await runScript(
        r'$func[calculate_total;price;qty]'
        r'$funcReturn[$calculate[$funcArg[price]*$funcArg[qty]]]'
        r'$funcEnd'
        r'$reply$c[]Total: $funcCall[calculate_total;15;4]',
      );

      expect(replies, hasLength(1));
      expect(replies[0], 'Total: 60');
    });
  });
}
