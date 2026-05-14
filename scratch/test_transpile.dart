import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:bot_creator_shared/utils/bdfd_lexer.dart';
import 'package:bot_creator_shared/utils/bdfd_parser.dart';
import 'dart:convert';

void main() {
  final script = r'''
$setUserVar[test;exist;1494544143081279532]
$getUserVar[test;1494544143081279532] coins.
''';

  final lexer = BdfdLexer();
  final tokens = lexer.tokenize(script);
  final parser = BdfdParser();
  final parseResult = parser.parseTokens(tokens.tokens);
  
  final transpiler = BdfdAstTranspiler();
  final transpileResult = transpiler.transpile(parseResult.ast);
  
  print(jsonEncode(transpileResult.actions.map((a) => {
    'type': a.type.name,
    'payload': a.payload,
  }).toList()));
}
