import 'package:bot_creator_shared/utils/bdfd_lexer.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdLexer', () {
    List<String> summarizeTokens(BdfdLexerResult result) {
      return result.tokens
          .map((token) => '${token.type.name}:${token.lexeme}')
          .toList(growable: false);
    }

    test('tokenizes plain text as a single text token', () {
      final result = BdfdLexer().tokenize('Hello from Bot Creator');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), ['text:Hello from Bot Creator', 'eof:']);
    });

    test('tokenizes standalone BDFD commands without arguments', () {
      final result = BdfdLexer().tokenize(r'$nomention Hello');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$nomention',
        'text: Hello',
        'eof:',
      ]);
    });

    test('tokenizes bracketed commands and separators', () {
      final result = BdfdLexer().tokenize(r'$description[Hello;World]');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$description',
        'openBracket:[',
        'text:Hello',
        'semicolon:;',
        'text:World',
        'closeBracket:]',
        'eof:',
      ]);
    });

    test('tokenizes nested functions inside arguments', () {
      final result = BdfdLexer().tokenize(
        r'$if[$hasPerms[$authorID;administrator]==true;yes;no]',
      );

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$if',
        'openBracket:[',
        r'function:$hasPerms',
        'openBracket:[',
        r'function:$authorID',
        'semicolon:;',
        'text:administrator',
        'closeBracket:]',
        'text:==true',
        'semicolon:;',
        'text:yes',
        'semicolon:;',
        'text:no',
        'closeBracket:]',
        'eof:',
      ]);
    });

    test('tokenizes standalone closing brackets outside functions as text', () {
      final result = BdfdLexer().tokenize('Hello ]');
      
      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        'text:Hello ]',
        'eof:',
      ]);
    });

    test('reports unclosed bracket diagnostics at the opening location', () {
      final result = BdfdLexer().tokenize(r'$title[Line 1');

      expect(result.hasErrors, isTrue);
      expect(result.diagnostics, hasLength(1));
      expect(
        result.diagnostics.first.message,
        r'Unclosed bracket for function $title.',
      );
      expect(result.diagnostics.first.column, 7);
    });

    test('tracks token line and column across multiline scripts', () {
      final result = BdfdLexer().tokenize('before\n\$title[after]');
      final functionToken = result.tokens.firstWhere(
        (token) => token.type == BdfdTokenType.function,
      );

      expect(functionToken.line, 2);
      expect(functionToken.column, 1);
    });

    test('preserves Markdown link brackets inside function arguments', () {
      final result = BdfdLexer().tokenize(
        r'$description[Check **[port 16](https://example.com/status)**]',
      );

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$description',
        'openBracket:[',
        'text:Check **[port 16](https://example.com/status)**',
        'closeBracket:]',
        'eof:',
      ]);
    });

    test('preserves JSON array brackets inside function arguments', () {
      final result = BdfdLexer().tokenize(r'$jsonParse[{"arr":[1,2,3]}]');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$jsonParse',
        'openBracket:[',
        'text:{"arr":[1,2,3]}',
        'closeBracket:]',
        'eof:',
      ]);
    });

    test('handles nested function inside literal brackets', () {
      final result = BdfdLexer().tokenize(
        r'$description[text [before $username after] end]',
      );

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$description',
        'openBracket:[',
        'text:text [before ',
        r'function:$username',
        'text: after] end',
        'closeBracket:]',
        'eof:',
      ]);
    });

    test('handles nested function with brackets inside literal brackets', () {
      final result = BdfdLexer().tokenize(
        r'$description[pre [lit] $getVar[key] post [lit2] end]',
      );

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$description',
        'openBracket:[',
        'text:pre [lit] ',
        r'function:$getVar',
        'openBracket:[',
        'text:key',
        'closeBracket:]',
        'text: post [lit2] end',
        'closeBracket:]',
        'eof:',
      ]);
    });

    test('tokenizes lone brackets as text outside function brackets', () {
      final result = BdfdLexer().tokenize('text ] more');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        'text:text ] more',
        'eof:',
      ]);
    });
    
    test('supports bracketed context IDs in variable names', () {
      final result = BdfdLexer().tokenize('user[123].test');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        'text:user[123].test',
        'eof:',
      ]);
    });

    // ── Escape sequences ─────────────────────────────────────────────────

    test(r'escaped bracket \[\] inside function argument produces text', () {
      final result = BdfdLexer().tokenize(r'$if[$args[1]==x]\[test\]$endif');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$if',
        'openBracket:[',
        r'function:$args',
        'openBracket:[',
        'text:1',
        'closeBracket:]',
        'text:==x',
        'closeBracket:]',
        'text:[test]',
        r'function:$endif',
        'eof:',
      ]);
    });

    test(r'escaped \$ prevents function scanning', () {
      final result = BdfdLexer().tokenize(r'Hello \$nomention');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [r'text:Hello $nomention', 'eof:']);
    });

    test(r'escaped \; inside function argument produces literal semicolon', () {
      final result = BdfdLexer().tokenize(r'$description[Hello\;World]');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$description',
        'openBracket:[',
        'text:Hello;World',
        'closeBracket:]',
        'eof:',
      ]);
    });

    test(r'escaped \] inside function argument produces literal bracket', () {
      final result = BdfdLexer().tokenize(r'$description[a\]b]');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$description',
        'openBracket:[',
        'text:a]b',
        'closeBracket:]',
        'eof:',
      ]);
    });

    test(r'lone backslash without special char is kept as text', () {
      final result = BdfdLexer().tokenize(r'Hello \ World');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [r'text:Hello \ World', 'eof:']);
    });

    test('greedy prefix-matching for functions concatenated with text', () {
      final result = BdfdLexer().tokenize(r'$replysfdsfsdf');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$reply',
        'text:sfdsfsdf',
        'eof:',
      ]);
    });

    test('greedy matching prefers longest valid function name', () {
      final result = BdfdLexer().tokenize(r'$getBotInvitetext');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$getBotInvite',
        'text:text',
        'eof:',
      ]);
    });

    test('treats unknown identifiers as functions (for loop variables etc)', () {
      final result = BdfdLexer().tokenize(r'$totallyFakeFunction');

      expect(result.diagnostics, isEmpty);
      expect(summarizeTokens(result), [
        r'function:$totallyFakeFunction',
        'eof:',
      ]);
    });
  });
}
