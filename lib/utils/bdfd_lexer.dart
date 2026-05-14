import 'bdfd_functions.dart';

enum BdfdTokenType { text, function, openBracket, closeBracket, semicolon, eof }

class BdfdToken {
  const BdfdToken({
    required this.type,
    required this.lexeme,
    required this.start,
    required this.end,
    required this.line,
    required this.column,
  });

  final BdfdTokenType type;
  final String lexeme;
  final int start;
  final int end;
  final int line;
  final int column;

  @override
  String toString() {
    return 'BdfdToken(type: $type, lexeme: $lexeme, start: $start, end: $end, line: $line, column: $column)';
  }
}

class BdfdLexerDiagnostic {
  const BdfdLexerDiagnostic({
    required this.message,
    required this.start,
    required this.end,
    required this.line,
    required this.column,
  });

  final String message;
  final int start;
  final int end;
  final int line;
  final int column;

  @override
  String toString() {
    return 'BdfdLexerDiagnostic(message: $message, start: $start, end: $end, line: $line, column: $column)';
  }
}

class BdfdLexerResult {
  const BdfdLexerResult({required this.tokens, required this.diagnostics});

  final List<BdfdToken> tokens;
  final List<BdfdLexerDiagnostic> diagnostics;

  bool get hasErrors => diagnostics.isNotEmpty;
}

class BdfdLexer {
  BdfdLexerResult tokenize(String source) {
    final scanner = _BdfdScanner(source);
    return scanner.scan();
  }
}

class _BdfdScanner {
  _BdfdScanner(this.source);

  final String source;
  final List<BdfdToken> _tokens = <BdfdToken>[];
  final List<BdfdLexerDiagnostic> _diagnostics = <BdfdLexerDiagnostic>[];
  final List<_BdfdBracketFrame> _bracketStack = <_BdfdBracketFrame>[];

  int _index = 0;
  int _line = 1;
  int _column = 1;
  bool _mayOpenArgumentList = false;

  BdfdLexerResult scan() {
    while (!_isAtEnd) {
      final char = _peek();

      // Escape sequences: \$, \[, \], \; produce literal text.
      if (char == r'\' && !_isAtEnd) {
        final next = _peekNext();
        if (next == r'$' || next == '[' || next == ']' || next == ';') {
          _scanText();
          continue;
        }
      }

      if (_isFunctionStart()) {
        _scanFunction();
        continue;
      }

      if (char == '[' && _mayOpenArgumentList) {
        _scanOpenBracket();
        continue;
      }

      if (char == ']' && _bracketStack.isNotEmpty) {
        _scanCloseBracket();
        continue;
      }

      if (char == ';' && _bracketStack.isNotEmpty) {
        _scanSemicolon();
        continue;
      }

      _scanText();
    }

    for (final frame in _bracketStack) {
      _diagnostics.add(
        BdfdLexerDiagnostic(
          message: 'Unclosed bracket for function ${frame.functionLexeme}.',
          start: frame.start,
          end: frame.end,
          line: frame.line,
          column: frame.column,
        ),
      );
    }

    _tokens.add(
      BdfdToken(
        type: BdfdTokenType.eof,
        lexeme: '',
        start: _index,
        end: _index,
        line: _line,
        column: _column,
      ),
    );

    return BdfdLexerResult(
      tokens: List<BdfdToken>.unmodifiable(_tokens),
      diagnostics: List<BdfdLexerDiagnostic>.unmodifiable(_diagnostics),
    );
  }

  bool get _isAtEnd => _index >= source.length;

  String _peek() => source[_index];

  String _peekNext() => (_index + 1) < source.length ? source[_index + 1] : '';

  bool _isFunctionStart() {
    if (_isAtEnd || _peek() != r'$') {
      return false;
    }
    final next = _peekNext();
    return _isIdentifierStart(next);
  }

  bool _isIdentifierStart(String value) {
    if (value.isEmpty) {
      return false;
    }
    final codeUnit = value.codeUnitAt(0);
    return (codeUnit >= 65 && codeUnit <= 90) ||
        (codeUnit >= 97 && codeUnit <= 122) ||
        value == '_';
  }

  bool _isIdentifierPart(String value) {
    if (value.isEmpty) {
      return false;
    }
    final codeUnit = value.codeUnitAt(0);
    return _isIdentifierStart(value) || (codeUnit >= 48 && codeUnit <= 57);
  }

  String _advance() {
    final char = source[_index];
    _index += 1;
    if (char == '\n') {
      _line += 1;
      _column = 1;
    } else {
      _column += 1;
    }
    return char;
  }

  void _scanFunction() {
    final start = _index;
    final startLine = _line;
    final startColumn = _column;

    _advance(); // Skip '$'

    final identifierParts = <String>[];
    while (!_isAtEnd && _isIdentifierPart(_peek())) {
      identifierParts.add(_advance());
    }

    final fullId = identifierParts.join('');
    final normalized = fullId.toLowerCase();

    // Longest match search
    String? match;
    for (var i = normalized.length; i > 0; i--) {
      if (allBdfdFunctions.contains(normalized.substring(0, i))) {
        match = fullId.substring(0, i);
        break;
      }
    }

    if (match != null) {
      // Found a valid function! 
      // If we overshot (greedy identifier scan), backtrack.
      final overshot = fullId.length - match.length;
      for (var i = 0; i < overshot; i++) {
        _index--;
        _column--;
      }

      _tokens.add(
        BdfdToken(
          type: BdfdTokenType.function,
          lexeme: r'$' + match,
          start: start,
          end: _index,
          line: startLine,
          column: startColumn,
        ),
      );
      _mayOpenArgumentList = true;
    } else if (fullId.isNotEmpty) {
      // No known function match, but we have an identifier.
      // Tokenize the whole identifier as a function.
      // This is necessary to support dynamic variables like loop indices ($i, $j)
      // or custom variables that aren't in the global function list.
      _tokens.add(
        BdfdToken(
          type: BdfdTokenType.function,
          lexeme: r'$' + fullId,
          start: start,
          end: _index,
          line: startLine,
          column: startColumn,
        ),
      );
      _mayOpenArgumentList = true;
    } else {
      // Not a known function and no identifier. Treat the '$' as literal text.
      _tokens.add(
        BdfdToken(
          type: BdfdTokenType.text,
          lexeme: r'$',
          start: start,
          end: _index,
          line: startLine,
          column: startColumn,
        ),
      );
      _mayOpenArgumentList = false;
    }
  }

  void _scanOpenBracket() {
    final start = _index;
    final line = _line;
    final column = _column;
    _advance();
    final previousFunction =
        _tokens.isNotEmpty ? _tokens.last.lexeme : r'$unknown';
    _bracketStack.add(
      _BdfdBracketFrame(
        functionLexeme: previousFunction,
        start: start,
        end: _index,
        line: line,
        column: column,
      ),
    );
    _tokens.add(
      BdfdToken(
        type: BdfdTokenType.openBracket,
        lexeme: '[',
        start: start,
        end: _index,
        line: line,
        column: column,
      ),
    );
    _mayOpenArgumentList = false;
  }

  void _scanCloseBracket() {
    final start = _index;
    final line = _line;
    final column = _column;
    _advance();

    if (_bracketStack.isEmpty) {
      // Outside of function arguments, brackets are literal text.
      _tokens.add(
        BdfdToken(
          type: BdfdTokenType.text,
          lexeme: ']',
          start: start,
          end: _index,
          line: line,
          column: column,
        ),
      );
      _mayOpenArgumentList = false;
      return;
    }
    
    _bracketStack.removeLast();

    _tokens.add(
      BdfdToken(
        type: BdfdTokenType.closeBracket,
        lexeme: ']',
        start: start,
        end: _index,
        line: line,
        column: column,
      ),
    );
    _mayOpenArgumentList = false;
  }

  void _scanSemicolon() {
    final start = _index;
    final line = _line;
    final column = _column;
    _advance();
    _tokens.add(
      BdfdToken(
        type: BdfdTokenType.semicolon,
        lexeme: ';',
        start: start,
        end: _index,
        line: line,
        column: column,
      ),
    );
    _mayOpenArgumentList = false;
  }

  void _scanText() {
    final start = _index;
    final line = _line;
    final column = _column;
    final buffer = StringBuffer();
    _mayOpenArgumentList = false;

    while (!_isAtEnd) {
      // Handle escape sequences: \$, \[, \], \;
      if (_peek() == r'\' && (_index + 1) < source.length) {
        final next = source[_index + 1];
        if (next == r'$' || next == '[' || next == ']' || next == ';') {
          _advance(); // consume backslash
          buffer.write(_advance()); // consume and keep the escaped char
          continue;
        }
      }

      if (_isFunctionStart()) {
        break;
      }

      final char = _peek();

      // Track literal '[' inside function arguments for paired-bracket
      // balancing.  This lets Markdown links like [text](url) and JSON
      // arrays like [1,2,3] survive inside BDFD function arguments.
      if (char == '[' && _bracketStack.isNotEmpty) {
        _bracketStack.last.literalBracketDepth += 1;
        buffer.write(_advance());
        continue;
      }

      if (char == ']' && _bracketStack.isNotEmpty) {
        if (_bracketStack.last.literalBracketDepth > 0) {
          _bracketStack.last.literalBracketDepth -= 1;
          buffer.write(_advance());
          continue;
        }
        break;
      }

      if (char == ';' && _bracketStack.isNotEmpty) {
        if (_bracketStack.last.literalBracketDepth > 0) {
          buffer.write(_advance());
          continue;
        }
        break;
      }

      buffer.write(_advance());
    }

    if (buffer.isEmpty) {
      return;
    }

    _tokens.add(
      BdfdToken(
        type: BdfdTokenType.text,
        lexeme: buffer.toString(),
        start: start,
        end: _index,
        line: line,
        column: column,
      ),
    );
  }
}

class _BdfdBracketFrame {
  _BdfdBracketFrame({
    required this.functionLexeme,
    required this.start,
    required this.end,
    required this.line,
    required this.column,
  });

  final String functionLexeme;
  final int start;
  final int end;
  final int line;
  final int column;

  /// Tracks unmatched literal `[` characters inside this bracket frame so that
  /// a corresponding `]` is consumed as text rather than closing the function
  /// bracket.  This allows Markdown links (`[text](url)`) and JSON arrays
  /// (`[1,2,3]`) to appear inside BDFD function arguments.
  int literalBracketDepth = 0;
}
