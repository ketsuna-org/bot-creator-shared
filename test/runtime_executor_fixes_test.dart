import 'package:bot_creator_shared/actions/executors/control_flow_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

import 'helpers/variables_test_helpers.dart';

/// Comprehensive runtime executor tests for:
/// 1. $for[varName;val1;val2;...] list iteration (mode: 'list')
/// 2. $jsonArray[key;separator] splitting (initArray with separator)
/// 3. $json[] context initialization end-to-end
/// 4. $jsonKey[]/$jsonValue[] inside $jsonForEach end-to-end
void main() {
  // ─────────────────────────────────────────────────────────────────────
  // 1. DIRECT TESTS: _executeListForLoop (mode: 'list')
  // ─────────────────────────────────────────────────────────────────────
  group('executeControlFlowAction forLoop list mode', () {
    Future<bool> runListLoop({
      required Map<String, dynamic> payload,
      required Map<String, String> results,
      required List<List<Action>> executedBatches,
      required Map<String, String> variables,
      String Function(String input)? resolveValue,
    }) {
      return executeControlFlowAction(
        type: BotCreatorActionType.forLoop,
        payload: payload,
        resultKey: 'loop',
        results: results,
        variables: variables,
        botId: 'test_bot',
        resolveValue: resolveValue ?? (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          final resolvedActions = actions.map((a) {
            final resolvedPayload = a.payload.map((key, value) {
              if (value is String) {
                return MapEntry(
                  key,
                  resolveTemplatePlaceholders(value, variables),
                );
              }
              return MapEntry(key, value);
            });
            return Action(
              type: a.type,
              payload: resolvedPayload,
              key: a.key,
              enabled: a.enabled,
            );
          }).toList();
          executedBatches.add(resolvedActions);
          return <String, String>{'nested': 'ok'};
        },
      );
    }

    test('iterates over static resolved values', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];
      final variables = <String, String>{};

      await runListLoop(
        variables: variables,
        payload: <String, dynamic>{
          'mode': 'list',
          'varName': 'item',
          'values': <String>['sword', 'shield', 'potion'],
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{
                'content': 'Item: ((_loop.var.item))',
              },
            },
          ],
        },
        results: results,
        executedBatches: batches,
      );

      expect(batches, hasLength(3));
      expect(results['loop'], 'LOOP_3');
      expect(batches[0][0].payload['content'], 'Item: sword');
      expect(batches[1][0].payload['content'], 'Item: shield');
      expect(batches[2][0].payload['content'], 'Item: potion');
    });

    test('sets _loop.index (0-based) and _loop.count (1-based)', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];
      final variables = <String, String>{};

      await runListLoop(
        variables: variables,
        payload: <String, dynamic>{
          'mode': 'list',
          'varName': 'x',
          'values': <String>['a', 'b', 'c'],
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{
                'content': '#((_loop.count)) idx:((_loop.index)) = ((_loop.var.x))',
              },
            },
          ],
        },
        results: results,
        executedBatches: batches,
      );

      expect(batches, hasLength(3));
      expect(batches[0][0].payload['content'], '#1 idx:0 = a');
      expect(batches[1][0].payload['content'], '#2 idx:1 = b');
      expect(batches[2][0].payload['content'], '#3 idx:2 = c');
    });

    test('caps at maxIterations', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];

      await runListLoop(
        variables: <String, String>{},
        payload: <String, dynamic>{
          'mode': 'list',
          'varName': 'item',
          'values': List<String>.generate(10, (i) => 'val$i'),
          'maxIterations': 5,
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': '((_loop.var.item))'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
      );

      expect(batches, hasLength(5));
      expect(results['loop'], 'LOOP_5');
    });

    test('propagates __stopped__', () async {
      final results = <String, String>{};

      await executeControlFlowAction(
        type: BotCreatorActionType.forLoop,
        payload: <String, dynamic>{
          'mode': 'list',
          'varName': 'item',
          'values': <String>['a', 'b', 'c'],
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': '((_loop.var.item))'},
            },
          ],
        },
        resultKey: 'loop',
        results: results,
        variables: <String, String>{},
        botId: 'test_bot',
        resolveValue: (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          return <String, String>{'__stopped__': 'true'};
        },
      );

      expect(results['__stopped__'], 'true');
    });

    test('resolves runtime values via resolveValue', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];
      final variables = <String, String>{};

      await runListLoop(
        variables: variables,
        payload: <String, dynamic>{
          'mode': 'list',
          'varName': 'item',
          'values': <String>['((temp.custom))', 'static'],
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': '((_loop.var.item))'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
        resolveValue: (input) => input.replaceAll('((temp.custom))', 'dynamic'),
      );

      expect(batches, hasLength(2));
      expect(batches[0][0].payload['content'], 'dynamic');
      expect(batches[1][0].payload['content'], 'static');
    });

    test('handles empty values list', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];

      await runListLoop(
        variables: <String, String>{},
        payload: <String, dynamic>{
          'mode': 'list',
          'varName': 'item',
          'values': <String>[],
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': 'x'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
      );

      expect(batches, isEmpty);
      expect(results['loop'], 'LOOP_0');
    });

    test('cleans up loop variables after execution', () async {
      final results = <String, String>{};
      final variables = <String, String>{};

      await runListLoop(
        variables: variables,
        payload: <String, dynamic>{
          'mode': 'list',
          'varName': 'item',
          'values': <String>['a', 'b'],
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': '((_loop.var.item))'},
            },
          ],
        },
        results: results,
        executedBatches: <List<Action>>[],
      );

      expect(variables.containsKey('_loop.var.item'), isFalse);
      expect(variables.containsKey('_loop.index'), isFalse);
      expect(variables.containsKey('_loop.count'), isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 2. FULL PIPELINE: compile → execute end-to-end tests
  // ─────────────────────────────────────────────────────────────────────
    group(r'Full pipeline: $for list iteration end-to-end', () {
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

    test(r'$for[item;Alpha;Beta;Gamma] substitutes $item at runtime', () async {
      final (_, replies) = await runScript(
        r'$for[item;Alpha;Beta;Gamma]'
        r'$reply$c[]$loopCount: $item'
        r'$endfor',
      );

      expect(replies, hasLength(3));
      expect(replies[0], '1: Alpha');
      expect(replies[1], '2: Beta');
      expect(replies[2], '3: Gamma');
    });

    test(r'$for with reply inside body produces separate messages', () async {
      final (_, replies) = await runScript(
        r'$for[color;red;green;blue]'
        r'$reply$c[]Color $loopCount is $color'
        r'$endfor',
      );

      expect(replies, hasLength(3));
      expect(replies[0], 'Color 1 is red');
      expect(replies[1], 'Color 2 is green');
      expect(replies[2], 'Color 3 is blue');
    });

    test(r'$for with loopIndex and loopCount inside body', () async {
      final (_, replies) = await runScript(
        r'$for[num;10;20;30]'
        r'$reply$c[]idx=$loopIndex count=$loopCount val=$num'
        r'$endfor',
      );

      expect(replies, hasLength(3));
      expect(replies[0], 'idx=0 count=1 val=10');
      expect(replies[1], 'idx=1 count=2 val=20');
      expect(replies[2], 'idx=2 count=3 val=30');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 3. FULL PIPELINE: $json[] initialization + array operations
  // ─────────────────────────────────────────────────────────────────────
    group(r'Full pipeline: $json[] + $jsonArray end-to-end', () {
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

    test(r'$json[] + $jsonSet + $jsonArray produces correct count', () async {
      final (_, replies) = await runScript(
        r'$json[]'
        r'$jsonSet[items;sword,shield,potion,bow]'
        r'$jsonArray[items;,]'
        r'$reply$c[]Total: $jsonArrayCount[items]',
      );

      expect(replies, hasLength(1));
      expect(replies[0], 'Total: 4');
    });

    test(r'$json[raw] initializes from JSON literal', () async {
      final (_, replies) = await runScript(
        r'$json[{"Alice":95,"Bob":78}]'
        r'$reply$c[]Alice=$json[Alice] Bob=$json[Bob]',
      );

      expect(replies, hasLength(1));
      expect(replies[0], 'Alice=95 Bob=78');
    });

    test(r'$jsonArray + $jsonJoinArray round-trip', () async {
      final (_, replies) = await runScript(
        r'$json[]'
        r'$jsonSet[items;x,y,z]'
        r'$jsonArray[items;,]'
        r'$reply$c[]Joined: $jsonJoinArray[items; | ]',
      );

      expect(replies, hasLength(1));
      expect(replies[0], 'Joined: x | y | z');
    });

    test(r'$jsonArrayAppend after $jsonArray works', () async {
      final (_, replies) = await runScript(
        r'$json[]'
        r'$jsonSet[items;a,b]'
        r'$jsonArray[items;,]'
        r'$jsonArrayAppend[items;c]'
        r'$reply$c[]Count=$jsonArrayCount[items] Last=$json[items;2]',
      );

      expect(replies, hasLength(1));
      expect(replies[0], 'Count=3 Last=c');
    });

    test(r'$jsonArraySort sorts values', () async {
      final (_, replies) = await runScript(
        r'$json[]'
        r'$jsonSet[scores;30,10,20]'
        r'$jsonArray[scores;,]'
        r'$jsonArraySort[scores;desc]'
        r'$reply$c[]Top=$json[scores;0] Joined=$jsonJoinArray[scores;,]',
      );

      expect(replies, hasLength(1));
      // After desc sort: 30,20,10
      expect(replies[0], 'Top=30 Joined=30,20,10');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 4. FULL PIPELINE: $jsonForEach + $jsonKey[]/$jsonValue[]
  // ─────────────────────────────────────────────────────────────────────
    group(r'Full pipeline: $jsonForEach end-to-end', () {
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

    test(r'$jsonForEach iterates over object with $jsonKey[] and $jsonValue[]', () async {
      final (_, replies) = await runScript(
        r'$jsonParse[{"x":1,"y":2,"z":3}]'
        r'$jsonForEach[]'
        r'$reply$c[]$jsonKey[]=$jsonValue[]'
        r'$endJsonForEach',
      );

      // Should produce 3 replies: x=1, y=2, z=3
      expect(replies, hasLength(3));
      expect(replies, containsAll(<String>['x=1', 'y=2', 'z=3']));
    });

    test(r'$jsonForEach with $jsonValue[] reads value correctly', () async {
      final (variables, replies) = await runScript(
        r'$jsonParse[{"name":"hello","count":42}]'
        r'$jsonForEach[]'
        r'$var[lastkey;$jsonKey[]]'
        r'$var[lastval;$jsonValue[]]'
        r'$endJsonForEach'
        r'$reply$c[]Last: $var[lastkey]=$var[lastval]',
      );

      expect(replies, hasLength(1));
      // After iterating both keys, the last one depends on Map order.
      // Just verify the format is correct.
      expect(replies[0], anyOf('Last: name=hello', 'Last: count=42'));
    });

    test(r'$jsonForEach iterates over a JSON array with $jsonValue[]', () async {
      final (_, replies) = await runScript(
        r'$jsonParse[["sword","shield","potion"]]'
        r'$jsonForEach[]'
        r'$reply$c[]Item $loopCount: $jsonValue[]'
        r'$endJsonForEach',
      );

      expect(replies, hasLength(3));
      expect(replies[0], 'Item 1: sword');
      expect(replies[1], 'Item 2: shield');
      expect(replies[2], 'Item 3: potion');
    });

    test(r'$jsonForEach over array sets $jsonIndex correctly', () async {
      final (_, replies) = await runScript(
        r'$jsonParse[[10,20,30]]'
        r'$jsonForEach[]'
        r'$reply$c[]index=$jsonIndex[] val=$jsonValue[]'
        r'$endJsonForEach',
      );

      expect(replies, hasLength(3));
      expect(replies[0], 'index=0 val=10');
      expect(replies[1], 'index=1 val=20');
      expect(replies[2], 'index=2 val=30');
    });

    test(r'$jsonForEach over named array path works', () async {
      final (_, replies) = await runScript(
        r'$json[]'
        r'$jsonSet[items;sword,shield,potion,bow]'
        r'$jsonArray[items;,]'
        r'$jsonForEach[items]'
        r'$reply$c[]- $jsonValue[]'
        r'$endJsonForEach',
      );

      expect(replies, hasLength(4));
      expect(replies[0], '- sword');
      expect(replies[1], '- shield');
      expect(replies[2], '- potion');
      expect(replies[3], '- bow');
    });

    test(r'$jsonForEach over empty array produces no iterations', () async {
      final (_, replies) = await runScript(
        r'$jsonParse[[]]'
        r'$jsonForEach[]'
        r'$reply$c[]$jsonValue[]'
        r'$endJsonForEach',
      );

      expect(replies, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 5. COMBINED: $for + $json workflow (user scenario)
  // ─────────────────────────────────────────────────────────────────────
    group(r'Full pipeline: combined $for + $json workflows', () {
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

    test('user scenario: list iteration with embed fields', () async {
      final (_, replies) = await runScript(
        r'$nomention'
        r'$title[Items]'
        r'$for[item;sword;shield;potion;bow]'
        r'$addField[Item $loopCount;$item;yes]'
        r'$endfor',
      );

      // Should produce one respondWithMessage with embed fields.
      // The reply is empty text but the embed contains the fields.
      expect(replies, hasLength(1));
      // The reply content is empty (just the embed).
      expect(replies[0], '');
    });

    test(r'$jsonValue[path] standalone reads from JSON context', () async {
      final (_, replies) = await runScript(
        r'$jsonParse[{"a":"hello","b":"world"}]'
        r'$reply$c[]$jsonValue[a] and $jsonValue[b]',
      );

      expect(replies, hasLength(1));
      expect(replies[0], 'hello and world');
    });

    test(r'$textSplit + $splitText integration', () async {
      final (_, replies) = await runScript(
        r'$textSplit[red,green,blue;,]'
        r'$reply$c[]First=$splitText[1] Second=$splitText[2] Len=$getTextSplitLength',
      );

      expect(replies, hasLength(1));
      expect(replies[0], 'First=red Second=green Len=3');
    });
  });
}
