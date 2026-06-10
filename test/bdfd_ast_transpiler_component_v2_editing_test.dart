import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('ComponentV2 editing functions', () {
    test(r'$editButton modifies the button identified by custom ID', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('cmd_a')],
                <BdfdAstNode>[BdfdTextAst('Alpha')],
                <BdfdAstNode>[BdfdTextAst('primary')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('cmd_b')],
                <BdfdAstNode>[BdfdTextAst('Beta')],
                <BdfdAstNode>[BdfdTextAst('secondary')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('yes')],
                <BdfdAstNode>[BdfdTextAst('cmd_c')],
                <BdfdAstNode>[BdfdTextAst('Gamma')],
                <BdfdAstNode>[BdfdTextAst('danger')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$editButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('cmd_b')],
                <BdfdAstNode>[BdfdTextAst('BetaEdited')],
                <BdfdAstNode>[BdfdTextAst('success')],
                <BdfdAstNode>[BdfdTextAst('yes')],
                <BdfdAstNode>[BdfdTextAst('⭐')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final components = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      final buttons = components
          .where((c) => c['type'] == 'button')
          .toList(growable: false);
      expect(buttons[0]['label'], 'Alpha');
      expect(buttons[1]['label'], 'BetaEdited');
      expect(buttons[1]['style'], 'success');
      expect(buttons[1]['disabled'], true);
      expect(buttons[2]['label'], 'Gamma');
    });

    test(r'$editButton on a link-style button sets url not customId', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('https://old.example.com')],
                <BdfdAstNode>[BdfdTextAst('Visit')],
                <BdfdAstNode>[BdfdTextAst('link')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$editButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://old.example.com')],
                <BdfdAstNode>[BdfdTextAst('Go')],
                <BdfdAstNode>[BdfdTextAst('link')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final components = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      final button = components.firstWhere((c) => c['type'] == 'button');
      expect(button['label'], 'Go');
      // URL stays the same since we matched by it but didn't change it
      expect(button['url'], 'https://old.example.com');
    });

    test(r'$editSelectMenu updates min, max, and placeholder', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$newSelectMenu',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_1')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$editSelectMenu',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_1')],
                <BdfdAstNode>[BdfdTextAst('2')],
                <BdfdAstNode>[BdfdTextAst('3')],
                <BdfdAstNode>[BdfdTextAst('Updated placeholder')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final components = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      final menu = components.firstWhere((c) => c['type'] == 'selectMenu');
      expect(menu['placeholder'], 'Updated placeholder');
      expect(menu['minValues'], 2);
      expect(menu['maxValues'], 3);
    });

    test(
      r'$editSelectMenuOption updates the first option of the given menu',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$newSelectMenu',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('menu_x')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addSelectMenuOption',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('menu_x')],
                  <BdfdAstNode>[BdfdTextAst('Option A')],
                  <BdfdAstNode>[BdfdTextAst('val_a')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addSelectMenuOption',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('menu_x')],
                  <BdfdAstNode>[BdfdTextAst('Option B')],
                  <BdfdAstNode>[BdfdTextAst('val_b')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$editSelectMenuOption',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('menu_x')],
                  <BdfdAstNode>[BdfdTextAst('Option A Edited')],
                  <BdfdAstNode>[BdfdTextAst('val_a_edited')],
                  <BdfdAstNode>[BdfdTextAst('A helpful description')],
                  <BdfdAstNode>[BdfdTextAst('yes')],
                  <BdfdAstNode>[BdfdTextAst('⭐')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        final components = List<Map<String, dynamic>>.from(
          (result.actions.single.payload['components'] as Map)['items'] as List,
        );
        final options = components
            .where((c) => c['type'] == 'selectMenuOption')
            .toList(growable: false);
        expect(options[0]['label'], 'Option A Edited');
        expect(options[0]['value'], 'val_a_edited');
        expect(options[0]['description'], 'A helpful description');
        expect(options[0]['default'], true);
        expect(options[0]['emoji'], '⭐');
        expect(options[1]['label'], 'Option B');
      },
    );

    test(r'$editSelectMenuOption with empty description clears the field', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$newSelectMenu',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_y')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addSelectMenuOption',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_y')],
                <BdfdAstNode>[BdfdTextAst('Opt')],
                <BdfdAstNode>[BdfdTextAst('v')],
                <BdfdAstNode>[BdfdTextAst('Original desc')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$editSelectMenuOption',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_y')],
                <BdfdAstNode>[],
                <BdfdAstNode>[],
                <BdfdAstNode>[BdfdTextAst('')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final components = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      final opt = components.firstWhere((c) => c['type'] == 'selectMenuOption');
      expect(opt.containsKey('description'), isFalse);
    });
  });
}
