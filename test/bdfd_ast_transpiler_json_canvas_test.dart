import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('user/profile inline functions — standalone if & Canvas', () {
    test(r'standalone if hoists runtime json condition before if action', () {
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
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('in')],
                <BdfdAstNode>[BdfdTextAst('items')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$json',
                    arguments: [
                      <BdfdAstNode>[
                        BdfdFunctionCallAst(
                          name: r'$var',
                          arguments: [
                            <BdfdAstNode>[BdfdTextAst('in')],
                          ],
                        ),
                      ],
                      <BdfdAstNode>[
                        BdfdFunctionCallAst(
                          name: r'$message',
                          arguments: [
                            <BdfdAstNode>[BdfdTextAst('1')],
                          ],
                        ),
                      ],
                      <BdfdAstNode>[BdfdTextAst('enabled')],
                    ],
                  ),
                  BdfdTextAst('==true'),
                ],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(name: r'$reply'),
                  BdfdTextAst('enabled'),
                ],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(name: r'$reply'),
                  BdfdTextAst('disabled'),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[1].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[2].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[3].type, BotCreatorActionType.ifBlock);

      final ifPayload = result.actions[3].payload;
      final conditionVariable =
          (ifPayload['condition.variable'] ?? '').toString();
      expect(conditionVariable, contains('rtJson_'));
      expect(conditionVariable, contains('.json_0'));
      expect(ifPayload['condition.value'], 'true');
    });

    group('Canvas Functions', () {
      test(r'$canvasCreate transpiles to runtimeImageBlock with create op', () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(nodes: [
            BdfdFunctionCallAst(
              name: r'$canvasCreate',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('test')],
                <BdfdAstNode>[BdfdTextAst('200')],
                <BdfdAstNode>[BdfdTextAst('100')],
                <BdfdAstNode>[BdfdTextAst('#ff0000')],
              ],
            ),
          ]),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(1));
        expect(result.actions.single.type, BotCreatorActionType.runtimeImageBlock);

        final operations =
            (result.actions.single.payload['operations'] as List?) ?? [];
        expect(operations, hasLength(1));
        expect(operations[0], containsPair('op', 'create'));
        expect(operations[0], containsPair('width', '200'));
        expect(operations[0], containsPair('height', '100'));
        expect(operations[0], containsPair('color', '#ff0000'));
      });

      test(
          'canvas functions are collected into single runtimeImageBlock',
          () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(nodes: [
            BdfdFunctionCallAst(
              name: r'$canvasCreate',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('img')],
                <BdfdAstNode>[BdfdTextAst('300')],
                <BdfdAstNode>[BdfdTextAst('200')],
                <BdfdAstNode>[BdfdTextAst('black')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$canvasDrawText',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Hello!')],
                <BdfdAstNode>[BdfdTextAst('10')],
                <BdfdAstNode>[BdfdTextAst('20')],
                <BdfdAstNode>[BdfdTextAst('14')],
                <BdfdAstNode>[BdfdTextAst('white')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$canvasDrawRect',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('5')],
                <BdfdAstNode>[BdfdTextAst('5')],
                <BdfdAstNode>[BdfdTextAst('100')],
                <BdfdAstNode>[BdfdTextAst('30')],
                <BdfdAstNode>[BdfdTextAst('green')],
                <BdfdAstNode>[BdfdTextAst('yes')],
              ],
            ),
          ]),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(1));
        expect(
            result.actions.single.type, BotCreatorActionType.runtimeImageBlock);

        final operations =
            (result.actions.single.payload['operations'] as List?) ?? [];
        expect(operations, hasLength(3));
        expect(operations[0]['op'], 'create');
        expect(operations[1]['op'], 'drawText');
        expect(operations[1]['text'], 'Hello!');
        expect(operations[2]['op'], 'drawRect');
        expect(operations[2]['fill'], 'yes');
      });

      test('canvas block is flushed when a non-canvas function follows', () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(nodes: [
            BdfdFunctionCallAst(
              name: r'$canvasCreate',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('img')],
                <BdfdAstNode>[BdfdTextAst('100')],
                <BdfdAstNode>[BdfdTextAst('100')],
                <BdfdAstNode>[BdfdTextAst('white')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$canvasDrawCircle',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('50')],
                <BdfdAstNode>[BdfdTextAst('50')],
                <BdfdAstNode>[BdfdTextAst('30')],
                <BdfdAstNode>[BdfdTextAst('blue')],
                <BdfdAstNode>[BdfdTextAst('true')],
              ],
            ),
            // Non-canvas function should flush the image block
            BdfdFunctionCallAst(
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('result')],
                <BdfdAstNode>[BdfdTextAst('test')],
              ],
            ),
          ]),
        );

        expect(result.diagnostics, isEmpty);
        // Should have 2 actions: runtimeImageBlock + setTemporaryVariable
        expect(result.actions, hasLength(2));
        expect(
            result.actions[0].type, BotCreatorActionType.runtimeImageBlock);
        expect(result.actions[1].type,
            BotCreatorActionType.setTemporaryVariable);

        // The image block should have 2 operations
        final operations =
            (result.actions[0].payload['operations'] as List?) ?? [];
        expect(operations, hasLength(2));
        expect(operations[0]['op'], 'create');
        expect(operations[1]['op'], 'drawCircle');
      });

      test(r'second $canvasCreate starts a new block', () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(nodes: [
            BdfdFunctionCallAst(
              name: r'$canvasCreate',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('red')],
                <BdfdAstNode>[BdfdTextAst('50')],
                <BdfdAstNode>[BdfdTextAst('50')],
                <BdfdAstNode>[BdfdTextAst('red')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$canvasCreate',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('green')],
                <BdfdAstNode>[BdfdTextAst('100')],
                <BdfdAstNode>[BdfdTextAst('100')],
                <BdfdAstNode>[BdfdTextAst('green')],
              ],
            ),
          ]),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(2));
        expect(
            result.actions[0].type, BotCreatorActionType.runtimeImageBlock);
        expect(
            result.actions[1].type, BotCreatorActionType.runtimeImageBlock);

        // First block: 1 op (create red 50x50)
        final ops1 =
            (result.actions[0].payload['operations'] as List?) ?? [];
        expect(ops1[0]['width'], '50');

        // Second block: 1 op (create green 100x100)
        final ops2 =
            (result.actions[1].payload['operations'] as List?) ?? [];
        expect(ops2[0]['width'], '100');
      });
    });
  });
}
