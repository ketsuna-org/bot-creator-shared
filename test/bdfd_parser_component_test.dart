import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_lexer.dart';
import 'package:bot_creator_shared/utils/bdfd_parser.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdParser - component/interaction functions', () {
    test(r'parses $addButton with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$addButton[Click me;primary;btn1;no;]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'addbutton');
      expect(fn.arguments, hasLength(5));
    });

    test(r'parses $addSelectMenuOption with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$addSelectMenuOption[Option 1;opt1;Description;no]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'addselectmenuoption');
      expect(fn.arguments, hasLength(4));
    });

    test(r'parses $addSeparator without arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$addSeparator');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'addseparator');
      expect(fn.arguments, isEmpty);
    });

    test(r'parses $addTextDisplay with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$addTextDisplay[Hello world]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'addtextdisplay');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $addTextInput with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$addTextInput[Name;short;name;Enter name;no]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'addtextinput');
      expect(fn.arguments, hasLength(5));
    });

    test(r'parses $editButton with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$editButton[btn1;New label;secondary]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'editbutton');
      expect(fn.arguments, hasLength(3));
    });

    test(r'parses $editSelectMenu with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$editSelectMenu[menu1;Choose;1;3]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'editselectmenu');
      expect(fn.arguments, hasLength(4));
    });

    test(r'parses $editSelectMenuOption with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$editSelectMenuOption[opt1;New label;New desc;no]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'editselectmenuoption');
      expect(fn.arguments, hasLength(4));
    });

    test(r'parses $newModal with arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$newModal[My Modal;modal1]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'newmodal');
      expect(fn.arguments, hasLength(2));
    });

    test(r'parses $newSelectMenu with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$newSelectMenu[menu1;string;Choose;1;3]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'newselectmenu');
      expect(fn.arguments, hasLength(5));
    });

    test(r'parses $removeAllComponents and $removeAllComponents[]', () {
      for (final code in [
        r'$removeAllComponents',
        r'$removeAllComponents[]',
      ]) {
        final lexerResult = BdfdLexer().tokenize(code);
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'removeallcomponents');
      }
    });

    test(r'parses $removeButtons and $removeButtons[]', () {
      for (final code in [r'$removeButtons', r'$removeButtons[]']) {
        final lexerResult = BdfdLexer().tokenize(code);
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'removebuttons');
      }
    });

    test(r'parses $removeComponent with arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$removeComponent[btn1]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'removecomponent');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $defer with arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$defer');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'defer');
      expect(fn.arguments, isEmpty);
    });

    test(r'parses $input with arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$input[name]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'input');
      expect(fn.arguments, hasLength(1));
    });
  });
}
