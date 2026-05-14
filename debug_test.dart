import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';

void main() {
  final result = BdfdAstTranspiler().transpile(
    const BdfdScriptAst(
      nodes: [
        BdfdFunctionCallAst(
          name: r'$reply',
          arguments: [
            <BdfdAstNode>[
              BdfdTextAst('Mention='),
              BdfdFunctionCallAst(
                name: r'$mentionedChannels',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('1')],
                ],
              ),
              BdfdTextAst(', Fallback='),
              BdfdFunctionCallAst(
                name: r'$mentionedChannels',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('1')],
                  <BdfdAstNode>[BdfdTextAst('yes')],
                ],
              ),
            ],
          ],
        ),
      ],
    ),
  );

  print('Diagnostics length: ${result.diagnostics.length}');
  for (final d in result.diagnostics) {
    print('Diagnostic: ${d.message} (function: ${d.functionName})');
  }
}
