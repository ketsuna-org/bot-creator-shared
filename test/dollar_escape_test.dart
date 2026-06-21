import 'package:bot_creator_shared/utils/bdfd_lexer.dart';
import 'package:test/test.dart';

/// Verifies that $$ correctly escapes to a literal $ while still allowing
/// the following text to be rescanned for BDFD functions.
///
/// Regression: previously $$ was not recognized as an escape sequence in
/// _scanText(), so the second $ triggered _isFunctionStart() and created a
/// spurious function token - splitting the input and breaking bracket matching
/// inside function arguments.
void main() {
  group(r'$$ escape sequence', () {
    List<BdfdToken> lex(String source) =>
        BdfdLexer().tokenize(source).tokens;

    void expectTokens(String source, List<String> expectedLexemes) {
      final tokens = lex(source);
      final actual = tokens
          .where((t) => t.type != BdfdTokenType.eof)
          .map((t) => t.lexeme)
          .toList();
      expect(actual, expectedLexemes, reason: 'source: $source');
    }

    // -- $$ followed by identifier ----------------------------------------

    test(r'$$getVar[x] -> literal dollar + function getVar', () {
      expectTokens(r'$$getVar[x]', [r'$', r'$getVar', '[', 'x', ']']);
    });

    // -- $$$ followed by identifier ---------------------------------------
    // The middle $ is silently consumed as part of the $$ chain.

    test(r'$$$getVar[x] -> literal dollar + function getVar (triple)', () {
      expectTokens(r'$$$getVar[x]', [r'$', r'$getVar', '[', 'x', ']']);
    });

    // -- $$$$ followed by identifier --------------------------------------
    // Two $$ pairs -> two literal $, then function.

    test(r'$$$$getVar[x] -> two literal dollars + function getVar', () {
      expectTokens(r'$$$$getVar[x]', ['\$\$', r'$getVar', '[', 'x', ']']);
    });

    // -- $$ inside function argument (the original bug scenario) -----------

    test(r'$description[$$getVar[x]] — bracket inside description survives', () {
      final result = BdfdLexer().tokenize(r'$description[$$getVar[x]]');
      final types = result.tokens
          .where((t) => t.type != BdfdTokenType.eof)
          .map((t) => t.type.name)
          .toList();
      expect(types, [
        'function',      // $description
        'openBracket',
        'text',          // $
        'function',      // $getVar
        'openBracket',
        'text',          // x
        'closeBracket',
        'closeBracket',
      ]);
      expect(result.diagnostics, isEmpty);
    });

    // -- $$ not followed by identifier stays as literal text --------------

    test(r'$$ alone at end of input — both dollars are literal', () {
      // No following identifier, so second $ is also text.
      expectTokens(r'$$', ['\$\$']);
    });

    test(r'$$zzz — zzz starts with identifier letter -> $zzz is a function', () {
      // "zzz" starts with 'z' (identifier-start), so after $$ escape
      // the second $ + zzz forms function token $zzz (even if unknown).
      expectTokens(r'$$zzz', [r'$', r'$zzz']);
    });

    // -- $$ inside markdown link pattern ----------------------------------

    test(r'**[$$getVar[val]\]** -> literal dollar + function + escaped ]', () {
      // '**[' are text, then $$ handler writes first $ (text = '**[$$'),
      // second $ breaks via _isFunctionStart -> text token is '**[$'.
      expectTokens(
        r'**[$$getVar[val]\]**',
        [r'**[$', r'$getVar', '[', 'val', ']', ']**'],
      );
    });

    // -- $$$ with known function text -------------------------------------

    test(r'$$$text[hello] -> literal dollar + function $text', () {
      expectTokens(r'$$$text[hello]', [r'$', r'$text', '[', 'hello', ']']);
    });
  });

  group(r'\] escape — literal bracket balance', () {

    // Regression: the \] escape handler wrote ] to the buffer but did NOT
    // decrement literalBracketDepth, so a paired [ ... \] inside function
    // arguments left literalBracketDepth permanently > 0.  The outer ]
    // was then consumed as text instead of closing the function bracket.

    test(r'$description[a\]b] — outer bracket closes correctly', () {
      final r = BdfdLexer().tokenize(r'$description[a\]b]');
      expect(r.diagnostics, isEmpty);
      final types = r.tokens
          .where((t) => t.type != BdfdTokenType.eof)
          .map((t) => t.type.name)
          .toList();
      expect(types, [
        'function',      // $description
        'openBracket',
        'text',          // a]b
        'closeBracket',  // ← the final ] must be a closeBracket, not text
      ]);
    });

    test(r'$description[a\]b\]c] — multiple escapes, outer bracket ok', () {
      final r = BdfdLexer().tokenize(r'$description[a\]b\]c]');
      expect(r.diagnostics, isEmpty);
      final types = r.tokens
          .where((t) => t.type != BdfdTokenType.eof)
          .map((t) => t.type.name)
          .toList();
      expect(types, [
        'function',
        'openBracket',
        'text',          // a]b]c
        'closeBracket',
      ]);
    });

    test(r'$description[text\]] — escaped ] at end, outer bracket ok', () {
      final r = BdfdLexer().tokenize(r'$description[text\]]');
      expect(r.diagnostics, isEmpty);
      final types = r.tokens
          .where((t) => t.type != BdfdTokenType.eof)
          .map((t) => t.type.name)
          .toList();
      expect(types, [
        'function',
        'openBracket',
        'text',          // text]
        'closeBracket',
      ]);
    });

    test(r'$description[**[$$getVar[val]\]($getVar[link])**] — full markdown',
        () {
      final r = BdfdLexer().tokenize(
          r'$description[**[$$getVar[val]\]($getVar[link])**]');
      expect(r.diagnostics, isEmpty,
          reason: 'outer bracket must close — no Unclosed bracket diagnostic');
    });
  });
}
