import '../lib/utils/bdfd_lexer.dart';

void main() {
  // EXACT user pattern: **[$$getVar[daily_reward_cash]\]($getVar[botlink])**
  final src = r'$description[**[$$getVar[daily_reward_cash]\]($getVar[botlink])**]';
  final r = BdfdLexer().tokenize(src);
  print('Tokens:');
  for (final t in r.tokens) {
    print('  ${t.type.name}: "${t.lexeme}"  [${t.start}-${t.end}]');
  }
  print('Diags: ${r.diagnostics.length}');
  for (final d in r.diagnostics) {
    print('  ${d.message} at ${d.start}');
  }
  print('');
  
  // Break it down: what's at each position?
  print('Source chars:');
  for (var i = 0; i < src.length; i++) {
    print('  $i: ${src[i] == r'\' ? '\\\\' : src[i]}');
  }
}
