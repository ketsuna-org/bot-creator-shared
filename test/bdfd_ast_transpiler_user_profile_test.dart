import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('user/profile inline functions — basics', () {
    test(r'$username without args resolves to ((user.username))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$username')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((user.username))');
    });

    test(r'$username[userID] resolves to ((user[id].username))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$username',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('123456')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((user[123456].username))');
    });

    test(r'$nickname without args resolves with fallback chains', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$nickname')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((member.nick|member.displayName|author.displayName|author.username))');
    });

    test(r'$nickname[userID] resolves with fallback chains', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$nickname',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('789')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((member[789].nick|member[789].displayName|user[789].displayName|user[789].username))');
    });

    test(r'$displayName without args resolves to fallback', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$displayName')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((member.nick|author.displayName|author.username))');
    });

    test(r'$displayName[userID] resolves to targeted fallback', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$displayName',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('456')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(
        embeds.single['description'],
        '((member[456].displayName|user[456].displayName))',
      );
    });

    test(r'$authorAvatar resolves to ((author.avatar))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$authorAvatar')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((author.avatar))');
    });

    test(r'$authorID resolves to ((author.id))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$authorID')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((author.id))');
    });

    test(r'$findUser resolves to ((user.id))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$findUser')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((user.id))');
    });

    test(r'$mentions transpiles to ((message.mentions)) placeholder', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdTextAst('Users: '),
            BdfdFunctionCallAst(name: r'$mentions'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(
        result.actions.single.payload['content'],
        'Users: ((message.mentions))',
      );
    });

    test(r'$mentioned[1;yes] transpiles to targeted mentions with author fallback', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$mentioned',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('1')],
                <BdfdAstNode>[BdfdTextAst('yes')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions.single.payload['content'], '((message.mentions[0]|author.id))');
    });

    test(r'$isbot[userID] transpiles to user dynamic isBot check', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$isbot',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('123456')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions.single.payload['content'], '((user[123456].isBot))');
    });

    test(r'$isbot without args transpiles to author.isBot', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$isbot',
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions.single.payload['content'], '((author.isBot))');
    });
  });
}
