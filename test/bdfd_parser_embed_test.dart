import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_lexer.dart';
import 'package:bot_creator_shared/utils/bdfd_parser.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdParser - embed functions', () {
    test(r'parses $title with arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$title[Server Info]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'title');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $description with arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$description[Welcome]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'description');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $color with arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$color[#ffcc00]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'color');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $footer with text and icon', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$footer[My footer;https://example.com/icon.png]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'footer');
      expect(fn.arguments, hasLength(2));
    });

    test(r'parses $footerIcon with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$footerIcon[https://example.com/icon.png]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'footericon');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $image with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$image[https://example.com/img.png]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'image');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $thumbnail with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$thumbnail[https://example.com/thumb.png]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'thumbnail');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $author with name, icon, and url', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$author[Jeremy;https://example.com/icon.png;https://example.com]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'author');
      expect(fn.arguments, hasLength(3));
    });

    test(r'parses $authorIcon with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$authorIcon[https://example.com/icon.png]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'authoricon');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $authorURL with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$authorURL[https://example.com]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'authorurl');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $addField with arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$addField[Name;Value;yes]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'addfield');
      expect(fn.arguments, hasLength(3));
    });

    test(r'parses $addTimestamp and $addTimestamp[]', () {
      for (final code in [r'$addTimestamp', r'$addTimestamp[]']) {
        final lexerResult = BdfdLexer().tokenize(code);
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'addtimestamp');
      }
    });

    test(r'parses $embeddedURL with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$embeddedURL[https://example.com]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'embeddedurl');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $addContainer with arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$addContainer[#ff0000]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'addcontainer');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $addSection with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$addSection[Section content]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'addsection');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $addThumbnail with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$addThumbnail[https://example.com/thumb.png]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'addthumbnail');
      expect(fn.arguments, hasLength(1));
    });
  });
}
