import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:test/test.dart';

/// Helper: compile BDFD source, return actions + diagnostics.
BdfdCompileResult compile(String source) => BdfdCompiler().compile(source);

void main() {
  group('Error handling', () {
    test('try/catch wraps in ifBlock checking error.message', () {
      final result = compile(r'''
        $nomention
        $try
          $sendMessage[Hello]
        $catch
          $sendMessage[An error occurred]
        $endtry
      ''');

      expect(result.hasErrors, isFalse);
      final ifBlock = result.actions.firstWhere(
        (a) => a.type == BotCreatorActionType.ifBlock,
      );
      expect(ifBlock.payload['condition.variable'], '((error.message))');
      expect(ifBlock.payload['condition.operator'], 'isEmpty');
    });

    test('try without catch silently suppresses errors', () {
      final result = compile(r'''
        $nomention
        $try
          $sendMessage[Hello]
        $endtry
      ''');

      expect(result.hasErrors, isFalse);
      final ifBlock = result.actions.firstWhere(
        (a) => a.type == BotCreatorActionType.ifBlock,
      );
      expect(ifBlock.payload['elseActions'], isEmpty);
    });

    test('suppressErrors wraps actions in suppressErrors ifBlock', () {
      final result = compile(r'''
        $suppressErrors
        $sendMessage[Hello]
      ''');

      expect(result.hasErrors, isFalse);
      final ifBlock = result.actions.firstWhere(
        (a) => a.type == BotCreatorActionType.ifBlock,
      );
      expect(ifBlock.payload['suppressErrors'], true);
    });

    test('suppressErrors with custom message', () {
      final result = compile(r'''
        $suppressErrors[Custom error!]
        $sendMessage[Hello]
      ''');

      expect(result.hasErrors, isFalse);
      final ifBlock = result.actions.firstWhere(
        (a) => a.type == BotCreatorActionType.ifBlock,
      );
      expect(ifBlock.payload['suppressErrorsMessage'], 'Custom error!');
    });

    test('error[message] in catch block returns placeholder', () {
      final result = compile(r'''
        $nomention
        $try
          $sendMessage[Hello]
        $catch
          Error: $error[message]
        $endtry
      ''');

      expect(result.hasErrors, isFalse);
      // The catch block content is nested inside the ifBlock's elseActions
      final ifBlock = result.actions.firstWhere(
        (a) => a.type == BotCreatorActionType.ifBlock,
      );
      final elseActions = (ifBlock.payload['elseActions'] as List?)
          ?.map((a) => Map<String, dynamic>.from(a as Map))
          .toList() ?? [];
      final allContent = elseActions
          .map((a) => ((a['payload'] as Map?) ?? const {})['content']?.toString() ?? '')
          .join(' | ');
      expect(allContent, contains('((error.message))'));
    });
  });

  group('Calculate', () {
    test('simple addition at compile time', () {
      final result = compile(r'$nomention $calculate[2+3]');
      expect(result.hasErrors, isFalse);
      final response = result.actions.firstWhere(
        (a) => a.type == BotCreatorActionType.respondWithMessage,
      );
      expect(response.payload['content'], contains('5'));
    });
  });

  group('setVar / getVar', () {
    test('setVar without userId creates setGlobalVariable', () {
      final result = compile(r'$setVar[coins;100]');
      expect(result.hasErrors, isFalse);
      expect(
        result.actions.any((a) => a.type == BotCreatorActionType.setGlobalVariable),
        isTrue,
      );
    });

    test('getVar without userId resolves to global placeholder', () {
      final result = compile(r'$nomention $getVar[coins]');
      expect(result.hasErrors, isFalse);
      final response = result.actions.firstWhere(
        (a) => a.type == BotCreatorActionType.respondWithMessage,
      );
      expect(response.payload['content'], contains('((global.coins))'));
    });
  });

  group('enableDecimals', () {
    test('enableDecimals[yes] creates temp variable for runtime', () {
      final result = compile(r'$enableDecimals[yes] $nomention $calculate[10/3]');
      expect(result.hasErrors, isFalse);
      expect(
        result.actions.any(
          (a) =>
              a.type == BotCreatorActionType.setTemporaryVariable &&
              a.payload['key'] == '_enableDecimals',
        ),
        isTrue,
      );
    });
  });
}
