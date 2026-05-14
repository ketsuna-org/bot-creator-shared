import 'package:bot_creator_shared/utils/bdfd_compiler.dart';

void main() {
  final result = BdfdCompiler().compile(r'$replyenabled');
  print('Has errors: ${result.hasErrors}');
  if (result.hasErrors) {
    for (final d in result.diagnostics) {
      print('Error: ${d.message} (Function: ${d.functionName})');
    }
  }
  print('Actions: ${result.actions.length}');
  if (result.actions.isNotEmpty) {
    print('Action 0 type: ${result.actions[0].type}');
    print('Action 0 payload: ${result.actions[0].payload}');
  }
}
