import 'package:bot_creator_shared/utils/template_resolver.dart';

void main() {
  final variables = {
    'user[1494544143081279532].bc_test': 'exist',
  };
  
  final content = '((user[1494544143081279532].bc_test)) coins.';
  
  final resolved = resolveTemplatePlaceholders(content, variables);
  print('Resolved: "$resolved"');
}
