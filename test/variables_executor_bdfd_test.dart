import 'dart:convert';

import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/utils/runtime_variables.dart';
import 'package:test/test.dart';

import 'helpers/variables_test_helpers.dart';

void main() {
  group('executeVariablesAction - compiled BDFD scripts', () {
    test(
      'compiled BDFD script resolves dynamic getServerVar keys with bc_ prefix args',
      () async {
        final store = MemoryBotDataStore(
          scopedVariables: <String, Map<String, Map<String, dynamic>>>{
            'guild': <String, Map<String, dynamic>>{
              'guild-1': <String, dynamic>{
                'wallet_db':
                    '{"currencies":[{"name":"bunbux"},{"name":"carrots"},{"name":"test"}]}',
              },
            },
          },
        );
        final variables = <String, String>{
          'guildId': 'guild-1',
          'args.2': 'bc_wallet_db',
          'args.3': 'carrots',
          'args.4': 'currencies',
        };
        await hydrateRuntimeVariables(
          store: store,
          botId: 'bot-1',
          runtimeVariables: variables,
          guildContextId: 'guild-1',
        );

        final compileResult = BdfdCompiler().compile(
          r'$var[s;$args[3]]'
          r'$var[in;$args[4]]'
          r'$jsonParse[$getServerVar[$args[2]]]'
          r'$for[$jsonArrayCount[$var[in]]]'
          r'$if[$json[$var[in];$i;name]==$var[s]]'
          r'$var[r;$i]'
          r'$endif'
          r'$endfor'
          r'$reply$var[r]',
        );

        expect(compileResult.hasErrors, isFalse);

        final replies = <String>[];
        final results = await executeCompiledActions(
          actions: compileResult.actions,
          store: store,
          variables: variables,
          replies: replies,
        );

        expect(
          variables['rtJson_0'],
          '{"currencies":[{"name":"bunbux"},{"name":"carrots"},{"name":"test"}]}',
        );
        expect(variables['rtJson_1.json_0'], '3');
        expect(variables['temp.r'], '1');
        expect(replies, <String>['1']);
        expect(results.values, contains('1'));
      },
    );

    group(r'runtime $jsonSet array support', () {
      // Helper: compile BDFD script + run, return (variables, replies).
      Future<(Map<String, String>, List<String>)> runScript(
        String script, {
        Map<String, String> vars = const <String, String>{},
      }) async {
        final compiled = BdfdCompiler().compile(script);
        expect(
          compiled.hasErrors,
          isFalse,
          reason: 'Compile errors: $script',
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

      test('creates array element from empty object', () async {
        final (_, replies) = await runScript(
          r'$jsonParse[$getServerVar[db]]'
          r'$jsonSet[currency;0;name;carrot]'
          r'$reply$jsonStringify',
        );
        expect(replies, hasLength(1));
        final decoded = jsonDecode(replies.first) as Map<String, dynamic>;
        expect(decoded['currency'], isA<List>());
        expect(
          (decoded['currency'] as List).first,
          containsPair('name', 'carrot'),
        );
      });

      test('mutates existing array element', () async {
        final (_, replies) = await runScript(
          r'$jsonParse[$getServerVar[db]]'
          r'$jsonSet[currency;1;name;carrot]'
          r'$reply$jsonStringify',
          vars: <String, String>{
            'guild.bc_db':
                '{"currency":[{"name":"bunbux"},{"name":"old"}]}',
          },
        );
        expect(replies, hasLength(1));
        final decoded = jsonDecode(replies.first) as Map<String, dynamic>;
        final list = decoded['currency'] as List;
        expect(list[0], containsPair('name', 'bunbux'));
        expect(list[1], containsPair('name', 'carrot'));
      });

      test('extends list with nulls when index is out of bounds', () async {
        final (_, replies) = await runScript(
          r'$jsonParse[$getServerVar[db]]'
          r'$jsonSet[arr;2;x;1]'
          r'$reply$jsonStringify',
          vars: <String, String>{'guild.bc_db': '{"arr":[]}'},
        );
        expect(replies, hasLength(1));
        final decoded = jsonDecode(replies.first) as Map<String, dynamic>;
        final arr = decoded['arr'] as List;
        expect(arr.length, 3);
        expect(arr[0], isNull);
        expect(arr[1], isNull);
        expect(arr[2], containsPair('x', 1));
      });

      test(
        r'nested $jsonParse inside $if does not leak prefix to outer scope',
        () async {
          final (vars, _) = await runScript(
            r'$jsonParse[$getServerVar[outer]]'
            r'$if[$json[flag]==yes]'
            r'$jsonParse[$getServerVar[inner]]'
            r'$var[inner;$json[innerKey]]'
            r'$endif'
            r'$var[outer;$json[outerKey]]',
            vars: <String, String>{
              'guild.bc_outer':
                  '{"outerKey":"outer_val","flag":"no"}',
              'guild.bc_inner': '{"innerKey":"inner_val"}',
            },
          );
          expect(vars['temp.outer'], 'outer_val');
          // inner branch was not taken (flag=="no"), inner var absent/empty.
          expect(vars['temp.inner'] ?? '', isEmpty);
        },
      );
    });
  });
}
