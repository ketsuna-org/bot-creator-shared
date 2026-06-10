import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('ComponentV2 builder functions', () {
    test(
      r'transpiles $addContainer into a ComponentV2 container component',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$addContainer',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('container1')],
                  <BdfdAstNode>[BdfdTextAst('#ff0000')],
                  <BdfdAstNode>[BdfdTextAst('no')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(
          result.actions.single.type,
          BotCreatorActionType.respondWithComponentV2,
        );
        final items = List<Map<String, dynamic>>.from(
          (result.actions.single.payload['components'] as Map)['items'] as List,
        );
        expect(items.single['type'], 'container');
        expect(items.single['accentColor'], '#ff0000');
      },
    );

    test(r'transpiles $addSection into a ComponentV2 section component', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addSection',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('section1')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithComponentV2,
      );
      final items = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      expect(items.single['type'], 'section');
      expect(items.single['id'], 'section1');
    });

    test(
      r'transpiles $addThumbnail into a ComponentV2 thumbnail component',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$addThumbnail',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('https://example.com/thumb.png')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(
          result.actions.single.type,
          BotCreatorActionType.respondWithComponentV2,
        );
        final items = List<Map<String, dynamic>>.from(
          (result.actions.single.payload['components'] as Map)['items'] as List,
        );
        expect(items.single['type'], 'thumbnail');
        expect(items.single['url'], 'https://example.com/thumb.png');
      },
    );

    test(r'$addMediaGallery creates an empty media gallery with an ID', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addMediaGallery',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('gallery1')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addMediaGalleryItem',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com/img1.png')],
                <BdfdAstNode>[BdfdTextAst('First image')],
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('gallery1')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addMediaGalleryItem',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com/img2.png')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithComponentV2,
      );
      final items = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      // gallery1 with one targeted item + one appended-to-last item
      expect(items, hasLength(1));
      expect(items.single['type'], 'mediaGallery');
      final galleryItems = List<Map<String, dynamic>>.from(
        items.single['items'] as List,
      );
      expect(galleryItems, hasLength(2));
      expect(galleryItems[0]['url'], 'https://example.com/img1.png');
      expect(galleryItems[0]['description'], 'First image');
      expect(galleryItems[1]['url'], 'https://example.com/img2.png');
      expect(galleryItems[1].containsKey('description'), isFalse);
    });

    test(
      r'$addMediaGallery starts a new gallery after a non-gallery component',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$addMediaGallery',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('gallery_a')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addMediaGalleryItem',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('https://example.com/a.png')],
                  <BdfdAstNode>[],
                  <BdfdAstNode>[],
                  <BdfdAstNode>[BdfdTextAst('gallery_a')],
                ],
              ),
              BdfdFunctionCallAst(name: r'$addSeparator'),
              BdfdFunctionCallAst(
                name: r'$addMediaGallery',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('gallery_b')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addMediaGalleryItem',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('https://example.com/b.png')],
                  <BdfdAstNode>[],
                  <BdfdAstNode>[],
                  <BdfdAstNode>[BdfdTextAst('gallery_b')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        final items = List<Map<String, dynamic>>.from(
          (result.actions.single.payload['components'] as Map)['items'] as List,
        );
        // gallery, separator, gallery
        expect(items, hasLength(3));
        expect(items[0]['type'], 'mediaGallery');
        expect(items[1]['type'], 'separator');
        expect(items[2]['type'], 'mediaGallery');
        expect(
          (items[0]['items'] as List).single['url'],
          'https://example.com/a.png',
        );
        expect(
          (items[2]['items'] as List).single['url'],
          'https://example.com/b.png',
        );
      },
    );

    test(r'rich V2 components produce respondWithComponentV2 action type', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addTextDisplay',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Hello ComponentV2')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$addSeparator'),
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('cmd_ok')],
                <BdfdAstNode>[BdfdTextAst('OK')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithComponentV2,
      );
      final items = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      expect(items[0]['type'], 'textDisplay');
      expect(items[1]['type'], 'separator');
      expect(items[2]['type'], 'button');
    });

    test(
      r'pure buttons without rich V2 keep respondWithMessage action type',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$addButton',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('no')],
                  <BdfdAstNode>[BdfdTextAst('cmd_a')],
                  <BdfdAstNode>[BdfdTextAst('Click')],
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
      },
    );
  });
}
