import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('user/profile inline functions — JSON runtime flow', () {
    test(
      r'deferred json reads continue after setServerVar using $jsonPretty',
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
              BdfdFunctionCallAst(name: r'$reply'),
              BdfdTextAst('Pretty: '),
              BdfdFunctionCallAst(
                name: r'$jsonPretty',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('1')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(4));
        expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
        expect(result.actions[1].type, BotCreatorActionType.setScopedVariable);
        expect(result.actions[2].type, BotCreatorActionType.runtimeJsonBlock);
        expect(result.actions[3].type, BotCreatorActionType.sendMessage);
        expect(result.actions[3].payload['targetType'], 'reply');

        final setValue = (result.actions[1].payload['value'] ?? '').toString();
        expect(setValue, contains('rtJson_'));
        expect(setValue, isNot(contains('.json_')));

        final replyContent =
            (result.actions[3].payload['content'] ?? '').toString();
        expect(replyContent, contains('Pretty: '));
        expect(replyContent, contains('rtJson_'));
        expect(replyContent, contains('.json_0'));
      },
    );

    test(r'finditem flow emits runtime json before if block', () {
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
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('idx')],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$jsonArrayIndex',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('items')],
                      <BdfdAstNode>[BdfdTextAst('potion')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$var',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('idx')],
                    ],
                  ),
                  BdfdTextAst('==-1'),
                ],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(name: r'$reply'),
                  BdfdTextAst('not found'),
                ],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(name: r'$reply'),
                  BdfdTextAst('found at '),
                  BdfdFunctionCallAst(
                    name: r'$var',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('idx')],
                    ],
                  ),
                  BdfdTextAst(': '),
                  BdfdFunctionCallAst(
                    name: r'$json',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('items')],
                      <BdfdAstNode>[
                        BdfdFunctionCallAst(
                          name: r'$var',
                          arguments: [
                            <BdfdAstNode>[BdfdTextAst('idx')],
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].type, BotCreatorActionType.ifBlock);
      expect(result.actions[1].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[2].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[3].type, BotCreatorActionType.ifBlock);

      final tempPayload = result.actions[2].payload;
      expect(tempPayload['key'], 'idx');
      expect((tempPayload['value'] ?? '').toString(), contains('rtJson_'));
      expect((tempPayload['value'] ?? '').toString(), contains('.json_0'));

      final conditionVariable =
          (result.actions[3].payload['condition.variable'] ?? '').toString();
      expect(conditionVariable, '((temp.idx))');

      final elseActions = List<Map<String, dynamic>>.from(
        result.actions[3].payload['elseActions'] as List? ?? const [],
      );
      expect(elseActions, hasLength(2));
      expect(elseActions[0]['type'], 'runtimeJsonBlock');
      expect(elseActions[1]['type'], 'sendMessage');
      expect(
        (elseActions[1]['payload'] as Map<String, dynamic>)['targetType'],
        'reply',
      );

      final elseContent =
          (elseActions[1]['payload'] as Map<String, dynamic>)['content']
              .toString();
      expect(elseContent, contains('((temp.idx))'));
      expect(elseContent, contains('rtJson_1.json_0'));
    });

    test(r'try block flushes runtime json before temp var actions', () {
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
            BdfdFunctionCallAst(name: r'$try'),
            BdfdFunctionCallAst(
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('idx')],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$jsonArrayIndex',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('items')],
                      <BdfdAstNode>[
                        BdfdFunctionCallAst(
                          name: r'$message',
                          arguments: [
                            <BdfdAstNode>[BdfdTextAst('1')],
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdFunctionCallAst(
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('idx')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$catch'),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdTextAst('fallback'),
            BdfdFunctionCallAst(name: r'$endtry'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[1].type, BotCreatorActionType.ifBlock);

      final thenActions = List<Map<String, dynamic>>.from(
        result.actions[1].payload['thenActions'] as List? ?? const [],
      );
      expect(thenActions, hasLength(3));
      expect(thenActions[0]['type'], 'runtimeJsonBlock');
      expect(thenActions[1]['type'], 'setTemporaryVariable');
      expect(thenActions[2]['type'], 'sendMessage');
      expect(
        (thenActions[2]['payload'] as Map<String, dynamic>)['targetType'],
        'reply',
      );

      final bodyJsonPayload = Map<String, dynamic>.from(
        thenActions[0]['payload'] as Map? ?? const <String, dynamic>{},
      );
      expect((bodyJsonPayload['source'] ?? '').toString(), '((rtJson_0))');

      final tempPayload = Map<String, dynamic>.from(
        thenActions[1]['payload'] as Map? ?? const <String, dynamic>{},
      );
      expect(tempPayload['key'], 'idx');
      expect((tempPayload['value'] ?? '').toString(), contains('rtJson_'));
      expect((tempPayload['value'] ?? '').toString(), contains('.json_0'));
      expect(
        (thenActions[2]['payload'] as Map<String, dynamic>)['content'],
        '((temp.idx))',
      );

      final elseActions = List<Map<String, dynamic>>.from(
        result.actions[1].payload['elseActions'] as List? ?? const [],
      );
      expect(elseActions, hasLength(1));
      expect(elseActions.single['type'], 'sendMessage');
      expect(
        (elseActions.single['payload'] as Map<String, dynamic>)['targetType'],
        'reply',
      );
    });

    test(r'runtime temp var is emitted before a runtime for loop', () {
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
                <BdfdAstNode>[BdfdTextAst('looping')],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$jsonArrayCount',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('currencies')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$for',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$var',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('looping')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdFunctionCallAst(name: r'$i'),
            BdfdFunctionCallAst(name: r'$endfor'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[1].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[2].type, BotCreatorActionType.forLoop);
      expect(result.actions[2].payload['iterations'], '((temp.looping))');
    });

    test(r'runtime loop body keeps temp setter actions in bodyActions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$for',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$message',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('1')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('current')],
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdFunctionCallAst(
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('current')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$endfor'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.forLoop);

      final bodyActions = List<Map<String, dynamic>>.from(
        result.actions.single.payload['bodyActions'] as List? ?? const [],
      );
      expect(bodyActions, hasLength(2));
      expect(bodyActions[0]['type'], 'setTemporaryVariable');
      expect(bodyActions[1]['type'], 'sendMessage');
      expect(
        (bodyActions[1]['payload'] as Map<String, dynamic>)['targetType'],
        'reply',
      );

      final tempPayload = Map<String, dynamic>.from(
        bodyActions[0]['payload'] as Map? ?? const <String, dynamic>{},
      );
      expect(tempPayload['key'], 'current');
      expect(tempPayload['value'], '((_loop.index))');
      expect(
        (bodyActions[1]['payload'] as Map<String, dynamic>)['content'],
        '((temp.current))',
      );
    });
  });
}
