import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdAstTranspiler — \$url function', () {
    test('transpiles \$url[encode;...] at compile-time', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$url',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('encode')],
                <BdfdAstNode>[BdfdTextAst('Hello world!!')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions.single.payload['content'], 'Hello+world%21%21');
    });

    test('transpiles \$url[decode;...] at compile-time', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$url',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('decode')],
                <BdfdAstNode>[BdfdTextAst('Hello+world%21%21')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions.single.payload['content'], 'Hello world!!');
    });

    test('emits runtime placeholder for dynamic text', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$url',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('encode')],
                <BdfdAstNode>[BdfdTextAst('((input))')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions.single.payload['content'], '((url[encode;((input))]))');
    });
  });
}
