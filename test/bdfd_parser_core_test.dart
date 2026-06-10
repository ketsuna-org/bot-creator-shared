import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_lexer.dart';
import 'package:bot_creator_shared/utils/bdfd_parser.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdParser', () {
    test('parses plain text into text nodes', () {
      final lexerResult = BdfdLexer().tokenize('Hello world');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      expect(result.ast.nodes, hasLength(1));
      expect(result.ast.nodes.single, isA<BdfdTextAst>());
      expect((result.ast.nodes.single as BdfdTextAst).value, 'Hello world');
    });

    test('parses nested functions with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$description[Hello $username in $if[((score))>10;gold;silver]]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      expect(result.ast.nodes, hasLength(1));

      final root = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(root.normalizedName, 'description');
      expect(root.arguments, hasLength(1));
      expect(root.arguments.single, hasLength(4));
      expect(root.arguments.single[0], isA<BdfdTextAst>());
      expect(root.arguments.single[1], isA<BdfdFunctionCallAst>());
      expect(root.arguments.single[2], isA<BdfdTextAst>());
      expect(root.arguments.single[3], isA<BdfdFunctionCallAst>());

      final nestedIf = root.arguments.single[3] as BdfdFunctionCallAst;
      expect(nestedIf.normalizedName, 'if');
      expect(nestedIf.arguments, hasLength(3));
    });

    test('keeps trailing empty arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$addField[Name;Value;]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final function = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(function.arguments, hasLength(3));
      expect(function.arguments[2], isEmpty);
    });

    test('reports missing closing brackets as parser diagnostics', () {
      final lexerResult = BdfdLexer().tokenize(r'$if[cond;yes');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.single.message,
        contains('Expected closing bracket'),
      );
    });
  });
}
