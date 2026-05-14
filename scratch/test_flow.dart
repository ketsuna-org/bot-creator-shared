import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'dart:convert';

void main() {
  final variables = <String, String>{};
  final scope = 'user';
  final contextId = '1494544143081279532';
  final referenceKey = 'bc_test';
  final runtimeValue = 'exist';
  
  // Simulation of setScopedVariable update
  final specificKey = '$scope[$contextId].$referenceKey';
  variables[specificKey] = runtimeValue;
  
  print('Map populated with key: $specificKey');
  
  // Simulation of TemplateResolver resolution
  final content = '((user[1494544143081279532].bc_test)) coins.';
  final resolved = resolveTemplatePlaceholders(content, variables);
  
  print('Resolved content: "$resolved"');
  
  if (resolved.contains('exist')) {
    print('SUCCESS: Variable resolved correctly.');
  } else {
    print('FAILURE: Variable did not resolve.');
    print('Map contents: ${jsonEncode(variables)}');
  }
}
