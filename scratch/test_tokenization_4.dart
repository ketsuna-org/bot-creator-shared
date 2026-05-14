import 'package:bot_creator_shared/utils/bdfd_compiler.dart';

void main() {
  final result = BdfdCompiler().compile(r'$reply$c[]enabled');
  print('Has errors: ${result.hasErrors}');
  print('Actions: ${result.actions.length}');
  if (result.actions.isNotEmpty) {
    print('Action 0 payload: ${result.actions[0].payload}');
  }
}
