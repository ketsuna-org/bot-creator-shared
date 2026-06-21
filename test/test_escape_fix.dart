import 'package:bot_creator_shared/utils/bdfd_lexer.dart';

void main() {
  final source = r'**[$$getVar[daily_reward_cash]\]($getVar[botlink])**';

  final result = BdfdLexer().tokenize(source);
  
  print('Source: $source');
  print('');
  print('Tokens:');
  for (final token in result.tokens) {
    print('  ${token.type.name}: "${token.lexeme}"');
  }
  print('');
  if (result.diagnostics.isNotEmpty) {
    print('Diagnostics:');
    for (final d in result.diagnostics) {
      print('  ${d.message}');
    }
  } else {
    print('No diagnostics');
  }
}
