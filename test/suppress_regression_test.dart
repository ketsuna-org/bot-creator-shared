import 'package:bot_creator_shared/utils/bdfd_compiler.dart';

void main() {
  final script = "\$suppresserrors\n\$sendmessage[Começou]\n\$splittext[10]\n\$sendmessage[Terminou]";

  final compileResult = BdfdCompiler().compile(script);
  
  if (compileResult.hasErrors) {
    print('COMPILE ERRORS:');
    for (final d in compileResult.diagnostics) {
      print('  [${d.severity.name}] ${d.message}');
    }
    return;
  }
  
  print('Actions count: ${compileResult.actions.length}');
  for (var i = 0; i < compileResult.actions.length; i++) {
    final action = compileResult.actions[i];
    final type = action.type.name;
    final suppressErrors = action.payload['suppressErrors'];
    final thenCount = (action.payload['thenActions'] as List?)?.length ?? 0;
    final content = action.payload['content'] ?? action.payload['text'] ?? '';
    print('  Action $i: type=$type, suppressErrors=$suppressErrors, thenActions=$thenCount, content="$content"');
    
    // If it's an ifBlock, show the inner actions too
    if (type == 'ifBlock' && thenCount > 0) {
      final thenActions = action.payload['thenActions'] as List;
      for (var j = 0; j < thenActions.length; j++) {
        final inner = thenActions[j] as Map;
        final innerPayload = inner['payload'] as Map?;
        print('    Inner $j: type=${inner['type']}, content="${innerPayload?['content'] ?? innerPayload?['text'] ?? ''}"');
      }
    }
  }
}
