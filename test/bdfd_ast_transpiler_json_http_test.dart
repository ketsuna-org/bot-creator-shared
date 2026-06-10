import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdAstTranspiler — JSON, HTTP & conditionals', () {
    test(
      'renders supported nested variable functions inline without diagnostic',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$description',
                arguments: [
                  <BdfdAstNode>[
                    BdfdTextAst('Hello '),
                    BdfdFunctionCallAst(name: r'$username'),
                  ],
                ],
              ),
            ],
          ),
        );

        expect(result.actions, hasLength(1));
        expect(result.diagnostics, isEmpty);

        final embeds = List<Map<String, dynamic>>.from(
          result.actions.single.payload['embeds'] as List,
        );
        expect(embeds.single['description'], 'Hello ((user.username))');
      },
    );

    test('transpiles http requests and result placeholders', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$httpAddHeader',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('authorization')],
                <BdfdAstNode>[BdfdTextAst('Bearer token')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$httpGet',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://api.example.com/cat')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[
                  BdfdTextAst('Image: '),
                  BdfdFunctionCallAst(
                    name: r'$httpResult',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('results')],
                      <BdfdAstNode>[BdfdTextAst('0')],
                      <BdfdAstNode>[BdfdTextAst('url')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(result.actions.first.type, BotCreatorActionType.httpRequest);
      expect(result.actions.first.key, '_bdfd_http_0');
      expect(result.actions.first.payload['method'], 'GET');
      expect(result.actions.first.payload['headers'], {
        'authorization': 'Bearer token',
      });

      final embeds = List<Map<String, dynamic>>.from(
        result.actions.last.payload['embeds'] as List,
      );
      expect(
        embeds.single['description'],
        r'Image: ((http.body.$.results[0].url))',
      );
    });

    test('reports httpResult without preceding request as error', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$httpResult')],
              ],
            ),
          ],
        ),
      );

      expect(result.actions, hasLength(1));
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$httpResult');
      expect(
        result.diagnostics.single.severity,
        BdfdTranspileDiagnosticSeverity.error,
      );
    });

    test('transpiles block if with elseif/else delimiters', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((score))>10')],
              ],
            ),
            BdfdTextAst('gold'),
            BdfdFunctionCallAst(
              name: r'$elseif',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((score))==10')],
              ],
            ),
            BdfdTextAst('silver'),
            BdfdFunctionCallAst(name: r'$else'),
            BdfdTextAst('bronze'),
            BdfdFunctionCallAst(name: r'$endif'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.ifBlock);

      final payload = result.actions.single.payload;
      expect(payload['condition.operator'], 'greaterThan');
      expect(payload['condition.value'], '10');

      final elseIfConditions = List<Map<String, dynamic>>.from(
        payload['elseIfConditions'] as List,
      );
      expect(elseIfConditions, hasLength(1));
      expect(elseIfConditions.single['condition.operator'], 'equals');

      final thenActions = List<Map<String, dynamic>>.from(
        payload['thenActions'] as List,
      );
      final elseActions = List<Map<String, dynamic>>.from(
        payload['elseActions'] as List,
      );
      final elseIfActions = List<Map<String, dynamic>>.from(
        elseIfConditions.single['actions'] as List,
      );

      expect((thenActions.single['payload'] as Map)['content'], 'gold');
      expect((elseIfActions.single['payload'] as Map)['content'], 'silver');
      expect((elseActions.single['payload'] as Map)['content'], 'bronze');
    });

    test('transpiles logical and-conditions and stop action', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[BdfdTextAst(r'$and[((a))==1;((b))==2]==true')],
                <BdfdAstNode>[BdfdTextAst('ok')],
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$stop')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      final payload = result.actions.single.payload;
      expect(payload['condition.group'], 'and');
      final grouped = List<Map<String, dynamic>>.from(
        payload['condition.conditions'] as List,
      );
      expect(grouped, hasLength(2));

      final elseActions = List<Map<String, dynamic>>.from(
        payload['elseActions'] as List,
      );
      expect(elseActions.single['type'], 'stop');
    });

    test('supports json parse/get/set/unset/stringify helpers', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{"user":{"name":"Nia","age":16}}')],
              ],
            ),
            BdfdTextAst('Name='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('name')],
              ],
            ),
            BdfdTextAst(', Age='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('age')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonSet',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('age')],
                <BdfdAstNode>[BdfdTextAst('19')],
              ],
            ),
            BdfdTextAst(', NewAge='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('age')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonUnset',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('name')],
              ],
            ),
            BdfdTextAst(', HasName='),
            BdfdFunctionCallAst(
              name: r'$jsonExists',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('name')],
              ],
            ),
            BdfdTextAst(', JSON='),
            BdfdFunctionCallAst(name: r'$jsonStringify'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        'Name=Nia, Age=16, NewAge=19, HasName=false, JSON={"user":{"age":19}}',
      );
    });

    test('supports json array helpers', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{"music":["A","B"]}')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonArrayAppend',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('music')],
                <BdfdAstNode>[BdfdTextAst('C')],
              ],
            ),
            BdfdTextAst('Count='),
            BdfdFunctionCallAst(
              name: r'$jsonArrayCount',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('music')],
              ],
            ),
            BdfdTextAst(', Removed='),
            BdfdFunctionCallAst(
              name: r'$jsonArrayShift',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('music')],
              ],
            ),
            BdfdTextAst(', Joined='),
            BdfdFunctionCallAst(
              name: r'$jsonJoinArray',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('music')],
                <BdfdAstNode>[BdfdTextAst(', ')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        'Count=3, Removed=A, Joined=B, C',
      );
    });

    test(
      'keeps invalid jsonParse non-blocking and returns empty JSON lookups',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$jsonParse',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('{invalid}')],
                ],
              ),
              BdfdTextAst('Value='),
              BdfdFunctionCallAst(
                name: r'$json',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('user')],
                  <BdfdAstNode>[BdfdTextAst('name')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(1));
        expect(result.actions.single.payload['content'], 'Value=');
      },
    );
  });
}
