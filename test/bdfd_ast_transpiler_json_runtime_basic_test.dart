import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('user/profile inline functions — JSON runtime basic', () {
    test(r'$jsonParse with runtime placeholder emits runtimeJsonBlock', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$getServerVar',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('data')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdTextAst('v='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('key')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      // Should have a runtimeJsonBlock action + a respondWithMessage
      final runtimeBlocks =
          result.actions
              .where((a) => a.type == BotCreatorActionType.runtimeJsonBlock)
              .toList();
      expect(runtimeBlocks, hasLength(1));

      final payload = runtimeBlocks.single.payload;
      expect(payload['source'], contains('(('));
      expect(payload['operations'], isList);
    });

    test(r'$jsonArrayAppend supports complex JSON objects at compile time', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{"items":[]}')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonArrayAppend',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('items')],
                <BdfdAstNode>[BdfdTextAst('{"name":"A","val":1}')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$jsonStringify'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        '{"items":[{"name":"A","val":1}]}',
      );
    });

    test(r'literal $jsonParse still works at compile-time (regression)', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{"a":1}')],
              ],
            ),
            BdfdTextAst('v='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('a')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(result.actions.single.payload['content'], 'v=1');
      // No runtimeJsonBlock when literal JSON
      expect(
        result.actions
            .where((a) => a.type == BotCreatorActionType.runtimeJsonBlock)
            .toList(),
        isEmpty,
      );
    });

    test(r'$jsonPretty does not corrupt double-spaces inside strings', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{"msg":"hello  world"}')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonPretty',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('4')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      final content = result.actions.single.payload['content'] as String;
      // The double-space inside the value MUST be preserved.
      expect(content, contains('"hello  world"'));
    });

    test(r'$jsonExists returns false when no JSON context', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdTextAst('exists='),
            BdfdFunctionCallAst(
              name: r'$jsonExists',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('key')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'exists=false');
    });

    test(r'$jsonSet supports complex JSON objects', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{}')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonSet',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('nested')],
                <BdfdAstNode>[BdfdTextAst('{"a":1,"b":2}')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$jsonStringify'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        '{"nested":{"a":1,"b":2}}',
      );
    });

    test(r'$argsCheck emits diagnostic for unknown operator', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$argsCheck',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('==')],
                <BdfdAstNode>[BdfdTextAst('3')],
                <BdfdAstNode>[BdfdTextAst('Need 3 args')],
              ],
            ),
          ],
        ),
      );

      // Should emit a diagnostic warning about unknown operator.
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.message, contains('unknown operator'));
      // Action should still be emitted (with fallback).
      expect(result.actions, isNotEmpty);
    });

    test('two consecutive deferred jsonParse blocks get unique prefixes', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$getServerVar',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('json1')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdTextAst('a='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('k')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$getServerVar',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('json2')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdTextAst('b='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('k')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final blocks =
          result.actions
              .where((a) => a.type == BotCreatorActionType.runtimeJsonBlock)
              .toList();
      expect(blocks, hasLength(2));
      // Keys must be different.
      expect(blocks[0].key, isNot(equals(blocks[1].key)));
    });

    test(
      r'deferred json is flushed before setServerVar action using $jsonStringify',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$jsonParse',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$getServerVar',
                      arguments: [
                        <BdfdAstNode>[BdfdTextAst('items_db')],
                      ],
                    ),
                  ],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$jsonArrayAppend',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('items')],
                  <BdfdAstNode>[BdfdTextAst('sword')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$setServerVar',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('items_db')],
                  <BdfdAstNode>[BdfdFunctionCallAst(name: r'$jsonStringify')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(2));
        expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
        expect(result.actions[1].type, BotCreatorActionType.setScopedVariable);

        final value = (result.actions[1].payload['value'] ?? '').toString();
        expect(value, contains('rtJson_'));
        expect(value, isNot(contains('.json_')));
      },
    );

    test(r'full additem script keeps runtimeJsonBlock before setServerVar', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$onlyIf',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((args.count))>0')],
                <BdfdAstNode>[BdfdTextAst('usage')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$getServerVar',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('items_db')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonArrayAppend',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('items')],
                <BdfdAstNode>[BdfdTextAst('sword')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$setServerVar',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('items_db')],
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$jsonStringify')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdTextAst('ok'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);

      final runtimeIndex = result.actions.indexWhere(
        (a) => a.type == BotCreatorActionType.runtimeJsonBlock,
      );
      final setVarIndex = result.actions.indexWhere(
        (a) => a.type == BotCreatorActionType.setScopedVariable,
      );

      expect(runtimeIndex, greaterThanOrEqualTo(0));
      expect(setVarIndex, greaterThanOrEqualTo(0));
      expect(runtimeIndex, lessThan(setVarIndex));

      final setValue =
          (result.actions[setVarIndex].payload['value'] ?? '').toString();
      expect(setValue, contains('rtJson_'));
      expect(setValue, isNot(contains('.json_')));
    });
  });
}
