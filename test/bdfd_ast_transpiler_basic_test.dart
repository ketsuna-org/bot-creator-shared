import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdAstTranspiler — basic transpilation', () {
    test('transpiles plain text into respondWithMessage', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(nodes: [BdfdTextAst('Hello world')]),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(result.actions.single.payload['content'], 'Hello world');
    });

    test(
      'transpiles embed-style functions into one respondWithMessage action',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$title',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('Server Info')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$description',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('Welcome back')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$color',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('#ffcc00')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addField',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('User')],
                  <BdfdAstNode>[BdfdTextAst('Jeremy')],
                  <BdfdAstNode>[BdfdTextAst('yes')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(1));

        final action = result.actions.single;
        final embeds = List<Map<String, dynamic>>.from(
          action.payload['embeds'] as List,
        );
        expect(action.type, BotCreatorActionType.respondWithMessage);
        expect(embeds, hasLength(1));
        expect(embeds.single['title'], 'Server Info');
        expect(embeds.single['description'], 'Welcome back');
        expect(embeds.single['color'], '#ffcc00');
        expect((embeds.single['fields'] as List).first, {
          'name': 'User',
          'value': 'Jeremy',
          'inline': 'yes',
        });
      },
    );

    test('preserves icon_urls when footericon and authoricon precede footer and author', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$footericon',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://footer.icon')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$footer',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('My Footer')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$authoricon',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://author.icon')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$author',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('My Author')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));

      final action = result.actions.single;
      final embeds = List<Map<String, dynamic>>.from(
        action.payload['embeds'] as List,
      );
      expect(embeds, hasLength(1));
      
      final footer = embeds.single['footer'] as Map<String, dynamic>;
      expect(footer['text'], 'My Footer');
      expect(footer['icon_url'], 'https://footer.icon');

      final author = embeds.single['author'] as Map<String, dynamic>;
      expect(author['name'], 'My Author');
      expect(author['icon_url'], 'https://author.icon');
    });

    test('transpiles if blocks to ifBlock actions with nested branches', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((score))>=80')],
                <BdfdAstNode>[BdfdTextAst('great')],
                <BdfdAstNode>[BdfdTextAst('retry')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));

      final action = result.actions.single;
      expect(action.type, BotCreatorActionType.ifBlock);
      expect(action.payload['condition.variable'], '((score))');
      expect(action.payload['condition.operator'], 'greaterOrEqual');
      expect(action.payload['condition.value'], '80');

      final thenActions = List<Map<String, dynamic>>.from(
        action.payload['thenActions'] as List,
      );
      final elseActions = List<Map<String, dynamic>>.from(
        action.payload['elseActions'] as List,
      );
      expect(thenActions.single['type'], 'respondWithMessage');
      expect((thenActions.single['payload'] as Map)['content'], 'great');
      expect(elseActions.single['type'], 'respondWithMessage');
      expect((elseActions.single['payload'] as Map)['content'], 'retry');
    });

    test('transpiles for loop blocks by repeating body actions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$for',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('3')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdTextAst('Ping'),
            BdfdFunctionCallAst(name: r'$endfor'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(3));
      for (final action in result.actions) {
        expect(action.type, BotCreatorActionType.sendMessage);
        expect(action.payload['targetType'], 'reply');
      }
      expect(result.actions[0].payload['content'], 'Ping');
      expect(result.actions[1].payload['content'], 'Ping');
      expect(result.actions[2].payload['content'], 'Ping');
    });

    test('supports nested loop blocks', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$for',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('2')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$loop',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('2')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdTextAst('Nested'),
            BdfdFunctionCallAst(name: r'$endloop'),
            BdfdFunctionCallAst(name: r'$endfor'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(4));
      expect(result.actions.first.payload['content'], 'Nested');
      expect(result.actions.last.payload['content'], 'Nested');
    });

    test('reports stray endfor delimiters', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(nodes: [BdfdFunctionCallAst(name: r'$endfor')]),
      );

      expect(result.actions, isEmpty);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.message, contains('Unexpected'));
      expect(result.diagnostics.single.functionName, r'$endfor');
    });

    test('flushes pending response before standalone action functions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdTextAst('Intro'),
            BdfdFunctionCallAst(
              name: r'$sendMessage',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Immediate')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(result.actions.first.payload['content'], 'Intro');
      expect(result.actions.last.payload['content'], 'Immediate');
    });

    test('reports unsupported functions as diagnostics', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$let',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('score')],
                <BdfdAstNode>[BdfdTextAst('10')],
              ],
            ),
          ],
        ),
      );

      expect(result.actions, isEmpty);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$let');
    });

    test('transpiles servername and other server-related properties dynamically when guild ID is passed', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$servername',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('123456')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], '((guild[123456].name))');
    });

    test('transpiles servername with nested serverID function', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$servername',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$serverid',
                    arguments: [],
                  )
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], '((guild[((guild.id))].name))');
    });
  });
}
