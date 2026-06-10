import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('user/profile inline functions — JSON runtime loops', () {
    test(
      r'weighted roll style runtime loop keeps nested json if flow dynamic',
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
                name: r'$var',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('in')],
                  <BdfdAstNode>[BdfdTextAst('items')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$var',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('target')],
                  <BdfdAstNode>[BdfdTextAst('sword')],
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
                        <BdfdAstNode>[
                          BdfdFunctionCallAst(
                            name: r'$var',
                            arguments: [
                              <BdfdAstNode>[BdfdTextAst('in')],
                            ],
                          ),
                        ],
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
                        <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
                        <BdfdAstNode>[BdfdTextAst('name')],
                      ],
                    ),
                    BdfdTextAst('=='),
                    BdfdFunctionCallAst(
                      name: r'$var',
                      arguments: [
                        <BdfdAstNode>[BdfdTextAst('target')],
                      ],
                    ),
                  ],
                ],
              ),
              BdfdFunctionCallAst(name: r'$reply'),
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
                  <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
                  <BdfdAstNode>[BdfdTextAst('weight')],
                ],
              ),
              BdfdFunctionCallAst(name: r'$endif'),
              BdfdFunctionCallAst(name: r'$endfor'),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(6));
        expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
        expect(
          result.actions[1].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[1].payload['key'], 'in');
        expect(
          result.actions[2].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[2].payload['key'], 'target');
        expect(result.actions[3].type, BotCreatorActionType.runtimeJsonBlock);
        expect(
          result.actions[4].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[4].payload['key'], 'looping');
        expect(result.actions[5].type, BotCreatorActionType.forLoop);
        expect(result.actions[5].payload['iterations'], '((temp.looping))');

        final bodyActions = List<Map<String, dynamic>>.from(
          result.actions[5].payload['bodyActions'] as List? ?? const [],
        );
        expect(bodyActions, hasLength(2));
        expect(bodyActions[0]['type'], 'runtimeJsonBlock');
        expect(bodyActions[1]['type'], 'ifBlock');

        final ifPayload = Map<String, dynamic>.from(
          bodyActions[1]['payload'] as Map? ?? const <String, dynamic>{},
        );
        final conditionVariable =
            (ifPayload['condition.variable'] ?? '').toString();
        expect(conditionVariable, contains('rtJson_'));
        expect(conditionVariable, contains('.json_0'));
        expect(ifPayload['condition.value'], '((temp.target))');

        final thenActions = List<Map<String, dynamic>>.from(
          ifPayload['thenActions'] as List? ?? const [],
        );
        expect(thenActions, hasLength(2));
        expect(thenActions[0]['type'], 'runtimeJsonBlock');
        expect(thenActions[1]['type'], 'sendMessage');
        expect(
          (thenActions[1]['payload'] as Map<String, dynamic>)['targetType'],
          'reply',
        );

        final weightContent =
            (thenActions[1]['payload'] as Map<String, dynamic>)['content']
                .toString();
        expect(weightContent, contains('rtJson_'));
        expect(weightContent, contains('.json_'));
      },
    );

    test(
      r'aggressive nested ifs in a runtime loop keep json reads executable',
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
                name: r'$var',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('in')],
                  <BdfdAstNode>[BdfdTextAst('items')],
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
                        <BdfdAstNode>[
                          BdfdFunctionCallAst(
                            name: r'$var',
                            arguments: [
                              <BdfdAstNode>[BdfdTextAst('in')],
                            ],
                          ),
                        ],
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
                        <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
                        <BdfdAstNode>[BdfdTextAst('enabled')],
                      ],
                    ),
                    BdfdTextAst('==true'),
                  ],
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
                        <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
                        <BdfdAstNode>[BdfdTextAst('weight')],
                      ],
                    ),
                    BdfdTextAst('>5'),
                  ],
                ],
              ),
              BdfdFunctionCallAst(name: r'$reply'),
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
                  <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
                  <BdfdAstNode>[BdfdTextAst('name')],
                ],
              ),
              BdfdTextAst(':'),
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
                  <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
                  <BdfdAstNode>[BdfdTextAst('weight')],
                ],
              ),
              BdfdFunctionCallAst(name: r'$endif'),
              BdfdFunctionCallAst(name: r'$endif'),
              BdfdFunctionCallAst(name: r'$endfor'),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(5));
        expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
        expect(
          result.actions[1].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[2].type, BotCreatorActionType.runtimeJsonBlock);
        expect(
          result.actions[3].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[4].type, BotCreatorActionType.forLoop);

        final bodyActions = List<Map<String, dynamic>>.from(
          result.actions[4].payload['bodyActions'] as List? ?? const [],
        );
        expect(bodyActions, hasLength(2));
        expect(bodyActions[0]['type'], 'runtimeJsonBlock');
        expect(bodyActions[1]['type'], 'ifBlock');

        final outerIfPayload = Map<String, dynamic>.from(
          bodyActions[1]['payload'] as Map? ?? const <String, dynamic>{},
        );
        expect(
          (outerIfPayload['condition.variable'] ?? '').toString(),
          contains('.json_0'),
        );

        final outerThenActions = List<Map<String, dynamic>>.from(
          outerIfPayload['thenActions'] as List? ?? const [],
        );
        expect(outerThenActions, hasLength(2));
        expect(outerThenActions[0]['type'], 'runtimeJsonBlock');
        expect(outerThenActions[1]['type'], 'ifBlock');

        final innerIfPayload = Map<String, dynamic>.from(
          outerThenActions[1]['payload'] as Map? ?? const <String, dynamic>{},
        );
        expect(
          (innerIfPayload['condition.variable'] ?? '').toString(),
          contains('.json_0'),
        );

        final innerThenActions = List<Map<String, dynamic>>.from(
          innerIfPayload['thenActions'] as List? ?? const [],
        );
        expect(innerThenActions, hasLength(2));
        expect(innerThenActions[0]['type'], 'runtimeJsonBlock');
        expect(innerThenActions[1]['type'], 'sendMessage');
        expect(
          (innerThenActions[1]['payload']
              as Map<String, dynamic>)['targetType'],
          'reply',
        );

        final nestedReply =
            (innerThenActions[1]['payload'] as Map<String, dynamic>)['content']
                .toString();
        expect(nestedReply, contains('rtJson_'));
        expect(nestedReply, contains('.json_'));
      },
    );
  });
}
