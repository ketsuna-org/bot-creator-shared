import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdAstTranspiler + Runtime — \$url nested support', () {
    test('transpiles and resolves \$url[encode; \$getMessage[...]]', () {
      // 1. Transpilation
      final transpiler = BdfdAstTranspiler();
      final script = BdfdScriptAst(
        nodes: [
          BdfdFunctionCallAst(
            name: r'$url',
            arguments: [
              <BdfdAstNode>[BdfdTextAst('encode')],
              <BdfdAstNode>[
                BdfdFunctionCallAst(
                  name: r'$getmessage',
                  arguments: [
                    <BdfdAstNode>[BdfdTextAst('123')],
                    <BdfdAstNode>[BdfdTextAst('456')],
                  ],
                )
              ],
            ],
          ),
        ],
      );

      final result = transpiler.transpile(script);
      expect(result.diagnostics, isEmpty);
      
      final transpiledContent = result.actions.single.payload['content'] as String;
      // Should be ((url[encode;((getMessage[123;456].content))]))
      expect(transpiledContent, contains('((url[encode;((getMessage[123;456].content))]))'));

      // 2. Runtime Resolution
      final vars = {
        'getMessage[123;456].content': 'Hello World!',
      };
      
      final finalResult = resolveTemplatePlaceholders(transpiledContent, vars);
      expect(finalResult, 'Hello+World%21');
    });
  });
}
