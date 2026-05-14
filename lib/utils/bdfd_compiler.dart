import 'package:bot_creator_shared/types/action.dart';

import 'bdfd_ast.dart';
import 'bdfd_ast_transpiler.dart';
import 'bdfd_lexer.dart';
import 'bdfd_parser.dart';

enum BdfdCompileDiagnosticSeverity { warning, error }

enum BdfdCompileDiagnosticStage { lexer, parser, transpiler }

class BdfdCompileDiagnostic {
  const BdfdCompileDiagnostic({
    required this.message,
    required this.severity,
    required this.stage,
    this.start,
    this.end,
    this.line,
    this.column,
    this.functionName,
  });

  final String message;
  final BdfdCompileDiagnosticSeverity severity;
  final BdfdCompileDiagnosticStage stage;
  final int? start;
  final int? end;
  final int? line;
  final int? column;
  final String? functionName;
}

class BdfdCompileResult {
  const BdfdCompileResult({
    required this.source,
    required this.lexerResult,
    required this.parserResult,
    required this.transpileResult,
    required this.ast,
    required this.actions,
    required this.diagnostics,
  });

  final String source;
  final BdfdLexerResult lexerResult;
  final BdfdParserResult parserResult;
  final BdfdTranspileResult transpileResult;
  final BdfdScriptAst ast;
  final List<Action> actions;
  final List<BdfdCompileDiagnostic> diagnostics;

  bool get hasErrors => diagnostics.any(
    (diagnostic) => diagnostic.severity == BdfdCompileDiagnosticSeverity.error,
  );
}

class BdfdCompiler {
  BdfdCompileResult compile(String source) {
    final compileStopwatch = Stopwatch()..start();
    final lexerResult = BdfdLexer().tokenize(source);
    final parserResult = BdfdParser().parseTokens(lexerResult.tokens);
    final transpileResult = BdfdAstTranspiler().transpile(parserResult.ast);
    compileStopwatch.stop();

    // Inject compilation timing into any debugProfile action.
    for (final action in transpileResult.actions) {
      if (action.type == BotCreatorActionType.debugProfile) {
        action.payload['compilationMs'] = compileStopwatch.elapsedMilliseconds;
        action.payload['sourceLength'] = source.length;
        action.payload['actionCount'] = transpileResult.actions.length;
        break;
      }
    }
    final diagnostics = <BdfdCompileDiagnostic>[
      ...lexerResult.diagnostics.map(
        (diagnostic) => BdfdCompileDiagnostic(
          message: diagnostic.message,
          severity: BdfdCompileDiagnosticSeverity.error,
          stage: BdfdCompileDiagnosticStage.lexer,
          start: diagnostic.start,
          end: diagnostic.end,
          line: diagnostic.line,
          column: diagnostic.column,
        ),
      ),
      ...parserResult.diagnostics.map(
        (diagnostic) => BdfdCompileDiagnostic(
          message: diagnostic.message,
          severity: BdfdCompileDiagnosticSeverity.error,
          stage: BdfdCompileDiagnosticStage.parser,
          start: diagnostic.start,
          end: diagnostic.end,
          line: diagnostic.line,
          column: diagnostic.column,
        ),
      ),
      ...transpileResult.diagnostics.map(
        (diagnostic) => BdfdCompileDiagnostic(
          message: diagnostic.message,
          severity:
              diagnostic.severity == BdfdTranspileDiagnosticSeverity.warning
                  ? BdfdCompileDiagnosticSeverity.warning
                  : BdfdCompileDiagnosticSeverity.error,
          stage: BdfdCompileDiagnosticStage.transpiler,
          start: diagnostic.start,
          end: diagnostic.end,
          line: _lineForOffset(source, diagnostic.start),
          column: _columnForOffset(source, diagnostic.start),
          functionName: diagnostic.functionName,
        ),
      ),
    ];

    return BdfdCompileResult(
      source: source,
      lexerResult: lexerResult,
      parserResult: parserResult,
      transpileResult: transpileResult,
      ast: parserResult.ast,
      actions: List<Action>.unmodifiable(transpileResult.actions),
      diagnostics: List<BdfdCompileDiagnostic>.unmodifiable(diagnostics),
    );
  }
}

int? _lineForOffset(String source, int? offset) {
  if (offset == null || offset < 0 || offset > source.length) {
    return null;
  }

  var line = 1;
  for (var index = 0; index < offset; index++) {
    if (source[index] == '\n') {
      line += 1;
    }
  }
  return line;
}

int? _columnForOffset(String source, int? offset) {
  if (offset == null || offset < 0 || offset > source.length) {
    return null;
  }

  var column = 1;
  for (var index = 0; index < offset; index++) {
    if (source[index] == '\n') {
      column = 1;
      continue;
    }
    column += 1;
  }
  return column;
}
