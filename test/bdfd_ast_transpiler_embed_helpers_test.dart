import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('embed helper functions', () {
    test(r'transpiles $addTimestamp without argument to "now"', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [BdfdFunctionCallAst(name: r'$addTimestamp')],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['timestamp'], 'now');
    });

    test(r'transpiles $addTimestamp with explicit value', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addTimestamp',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('2026-03-30T12:00:00Z')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['timestamp'], '2026-03-30T12:00:00Z');
    });

    test(r'transpiles $authorIcon standalone into author.icon_url', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$author',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Jeremy')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$authorIcon',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com/icon.png')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      final author = Map<String, dynamic>.from(embeds.single['author'] as Map);
      expect(author['name'], 'Jeremy');
      expect(author['icon_url'], 'https://example.com/icon.png');
    });

    test(r'transpiles $authorURL standalone into author.url', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$author',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Jeremy')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$authorURL',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      final author = Map<String, dynamic>.from(embeds.single['author'] as Map);
      expect(author['name'], 'Jeremy');
      expect(author['url'], 'https://example.com');
    });

    test(r'transpiles $embeddedURL into embed url', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$title',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Click me')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$embeddedURL',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['title'], 'Click me');
      expect(embeds.single['url'], 'https://example.com');
    });

    test(r'transpiles $footerIcon standalone into footer.icon_url', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$footer',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('My footer')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$footerIcon',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com/icon.png')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      final footer = Map<String, dynamic>.from(embeds.single['footer'] as Map);
      expect(footer['text'], 'My footer');
      expect(footer['icon_url'], 'https://example.com/icon.png');
    });

    test(r'transpiles $thumbnail into an embed thumbnail', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$thumbnail',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://embed-thumb.example.com')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['thumbnail'], {
        'url': 'https://embed-thumb.example.com',
      });
    });
  });
}
