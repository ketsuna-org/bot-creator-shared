import 'dart:convert';

import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/awaited_registration.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group(r'$eval', () {
    test('emits runBdfdScript action with script content', () {
      final result = BdfdCompiler().compile(r'$eval[$username]');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runBdfdScript);
      expect(result.actions[0].payload['scriptContent'], r'((user.username))');
    });

    test('passes through runtime placeholders in script content', () {
      final result = BdfdCompiler().compile(r'$eval[((opts.script))]');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runBdfdScript);
      expect(result.actions[0].payload['scriptContent'], '((opts.script))');
    });

    test('flushes pending response before eval', () {
      final result = BdfdCompiler().compile(
        'Hello\n'
        r'$eval[$username]',
      );
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.respondWithMessage);
      expect(result.actions[0].payload['content'], contains('Hello'));
      expect(result.actions[1].type, BotCreatorActionType.runBdfdScript);
    });

    test('eval with complex BDFD content', () {
      final result = BdfdCompiler().compile(r'$eval[$reply$c[]Hello $username]');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runBdfdScript);
    });

    test('eval with empty argument', () {
      final result = BdfdCompiler().compile(r'$eval[]');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runBdfdScript);
      expect(result.actions[0].payload['scriptContent'], '');
    });
  });

  group(r'$debug', () {
    test('emits debugProfile action', () {
      final result = BdfdCompiler().compile(r'$debug');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.debugProfile);
    });

    test('flushes pending response before debug', () {
      final result = BdfdCompiler().compile(
        'Hello\n'
        r'$debug',
      );
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.respondWithMessage);
      expect(result.actions[0].payload['content'], contains('Hello'));
      expect(result.actions[1].type, BotCreatorActionType.debugProfile);
    });

    test('produces correct action sequence with other functions', () {
      final result = BdfdCompiler().compile(
        r'$debug'
        '\n'
        r'$reply$c[]pong',
      );
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.debugProfile);
      expect(result.actions[1].type, BotCreatorActionType.sendMessage);
      expect(result.actions[1].payload['targetType'], 'reply');
    });

    test('carries compilation timing metadata', () {
      final result = BdfdCompiler().compile(r'$debug');
      expect(result.hasErrors, isFalse);
      final debugAction = result.actions[0];
      expect(debugAction.payload['compilationMs'], isA<int>());
      expect(debugAction.payload['sourceLength'], equals(6));
      expect(debugAction.payload['actionCount'], equals(1));
    });

    test('loop actions carry iteration metadata', () {
      final result = BdfdCompiler().compile(
        r'$debug'
        '\n'
        r'$for[3]'
        '\n'
        r'  $channelSendMessage[$channelID;iter $i]'
        '\n'
        r'$endfor',
      );
      expect(result.hasErrors, isFalse);
      // debugProfile + 3 sendMessage
      expect(result.actions, hasLength(4));
      expect(result.actions[0].type, BotCreatorActionType.debugProfile);
      for (var i = 1; i <= 3; i++) {
        final a = result.actions[i];
        expect(a.type, BotCreatorActionType.sendMessage);
        expect(a.payload['_debugLoopDepth'], equals(1));
        expect(a.payload['_debugLoopIteration'], equals(i - 1));
      }
    });

    test(
      'recursive awaitFunc produces different snapshots on each compilation',
      () async {
        // Simulate a callback command that echoes and re-arms:
        //   $message
        //   $awaitFunc[say]
        const script = r'$message$awaitFunc[say]';

        // First compilation (initial command execution)
        final first = BdfdCompiler().compile(script);
        expect(first.hasErrors, isFalse);
        final firstSet = first.actions.firstWhere(
          (a) => a.type == BotCreatorActionType.setScopedVariable,
        );
        expect(firstSet.payload['key'], 'await_say');
        expect(firstSet.payload['valueType'], 'json');
        final firstJson = firstSet.payload['jsonValue'] as String;
        final firstResolved = resolveTemplatePlaceholders(firstJson, {
          'author.id': '111',
          'channel.id': '222',
        });
        final firstValue = jsonDecode(firstResolved) as Map<String, dynamic>;
        final firstSnapshot = awaitedRegistrationSnapshot(firstValue);

        // Tiny delay so DateTime.now() differs
        await Future<void>.delayed(const Duration(milliseconds: 2));

        // Second compilation (callback re-arms)
        BdfdCompiler.clearCache();
        final second = BdfdCompiler().compile(script);
        expect(second.hasErrors, isFalse);
        final secondSet = second.actions.firstWhere(
          (a) => a.type == BotCreatorActionType.setScopedVariable,
        );
        final secondJson = secondSet.payload['jsonValue'] as String;
        final secondResolved = resolveTemplatePlaceholders(secondJson, {
          'author.id': '111',
          'channel.id': '222',
        });
        final secondValue = jsonDecode(secondResolved) as Map<String, dynamic>;
        final secondSnapshot = awaitedRegistrationSnapshot(secondValue);

        // Snapshots MUST differ for re-arm to be detected
        expect(
          secondSnapshot,
          isNot(firstSnapshot),
          reason:
              'Each compilation must produce a unique createdAt so that '
              'the re-arm check detects the change.',
        );
      },
    );

    test(
      'pre-compiled awaitFunc actions produce identical snapshots (no re-arm)',
      () {
        // When using workflow-mode (pre-compiled actions), the same action
        // JSON is reused. The createdAt is static → snapshots are identical
        // → re-arm is NOT detected.
        const script = r'$awaitFunc[echo]';
        final compiled = BdfdCompiler().compile(script);
        expect(compiled.hasErrors, isFalse);
        final action = compiled.actions.single;
        // Serialize to JSON and deserialize (simulating workflow-mode storage)
        final actionJson = action.toJson();

        final firstResolved = resolveTemplatePlaceholders(
          (actionJson['payload'] as Map)['jsonValue'] as String,
          {'author.id': '111', 'channel.id': '222'},
        );
        final firstSnapshot = awaitedRegistrationSnapshot(
          jsonDecode(firstResolved),
        );

        // Reuse same serialized action JSON (workflow mode)
        final secondResolved = resolveTemplatePlaceholders(
          (actionJson['payload'] as Map)['jsonValue'] as String,
          {'author.id': '111', 'channel.id': '222'},
        );
        final secondSnapshot = awaitedRegistrationSnapshot(
          jsonDecode(secondResolved),
        );

        // Same static payload → identical snapshots → no re-arm!
        expect(
          secondSnapshot,
          equals(firstSnapshot),
          reason:
              'Pre-compiled actions have a static createdAt, so '
              'snapshots are identical and re-arm is not detected.',
        );
      },
    );

    test(
      r'$deleteMessage and $deleteIn compile correctly',
      () {
        final compiler = BdfdCompiler();
        final result = compiler.compile(r'$deleteMessage[123;456]');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        expect(result.actions[0].type, BotCreatorActionType.deleteMessages);
        expect(result.actions[0].payload['channelId'], '123');
        expect(result.actions[0].payload['messageId'], '456');

        final result2 = compiler.compile(r'$deleteIn[5s]');
        expect(result2.hasErrors, isFalse);
        expect(result2.actions, hasLength(1));
        expect(result2.actions[0].type, BotCreatorActionType.deleteMessages);
        expect(result2.actions[0].payload['channelId'], '((channel.id))');
        expect(result2.actions[0].payload['messageId'], '((message.id))');
        expect(result2.actions[0].payload['delay'], '5s');

        final result3 = compiler.compile(r'$clear');
        expect(result3.hasErrors, isFalse);
        expect(result3.actions, hasLength(1));
        expect(result3.actions[0].type, BotCreatorActionType.deleteMessages);
        expect(result3.actions[0].payload['channelId'], '((channel.id))');
        expect(result3.actions[0].payload['count'], '((message.args[0]))');
        expect(result3.actions[0].payload.containsKey('onlyUserId'), isFalse);
        expect(result3.actions[0].payload.containsKey('removePinned'), isFalse);

        final result4 = compiler.compile(r'$clear[50]');
        expect(result4.hasErrors, isFalse);
        expect(result4.actions, hasLength(1));
        expect(result4.actions[0].type, BotCreatorActionType.deleteMessages);
        expect(result4.actions[0].payload['channelId'], '((channel.id))');
        expect(result4.actions[0].payload['count'], '50');
        expect(result4.actions[0].payload.containsKey('onlyUserId'), isFalse);
        expect(result4.actions[0].payload.containsKey('removePinned'), isFalse);

        final result5 = compiler.compile(r'$clear[50;77777;false]');
        expect(result5.hasErrors, isFalse);
        expect(result5.actions, hasLength(1));
        expect(result5.actions[0].type, BotCreatorActionType.deleteMessages);
        expect(result5.actions[0].payload['channelId'], '((channel.id))');
        expect(result5.actions[0].payload['count'], '50');
        expect(result5.actions[0].payload['onlyUserId'], '77777');
        expect(result5.actions[0].payload['removePinned'], 'false');
      },
    );

    group('scoped variable operations', () {
      test('setUserVar with 2 or 3 arguments compiles to scope user', () {
        final compiler = BdfdCompiler();
        final result = compiler.compile(r'$setUserVar[money;100]');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        expect(result.actions[0].type, BotCreatorActionType.setScopedVariable);
        expect(result.actions[0].payload['scope'], 'user');
        expect(result.actions[0].payload['key'], 'money');
        expect(result.actions[0].payload['value'], '100');
        expect(result.actions[0].payload.containsKey('contextId'), isFalse);

        final result2 = compiler.compile(r'$setUserVar[money;100;12345]');
        expect(result2.hasErrors, isFalse);
        expect(result2.actions, hasLength(1));
        expect(result2.actions[0].type, BotCreatorActionType.setScopedVariable);
        expect(result2.actions[0].payload['scope'], 'user');
        expect(result2.actions[0].payload['key'], 'money');
        expect(result2.actions[0].payload['value'], '100');
        expect(result2.actions[0].payload['contextId'], '12345');
      });

      test('setUserVar with 4 arguments compiles to scope guildMember', () {
        final compiler = BdfdCompiler();
        final result = compiler.compile(r'$setUserVar[money;100;12345;67890]');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        expect(result.actions[0].type, BotCreatorActionType.setScopedVariable);
        expect(result.actions[0].payload['scope'], 'guildMember');
        expect(result.actions[0].payload['key'], 'money');
        expect(result.actions[0].payload['value'], '100');
        expect(result.actions[0].payload['contextId'], '67890:12345');

        final result2 = compiler.compile(r'$setUserVar[money;100;;67890]');
        expect(result2.hasErrors, isFalse);
        expect(result2.actions, hasLength(1));
        expect(result2.actions[0].type, BotCreatorActionType.setScopedVariable);
        expect(result2.actions[0].payload['scope'], 'guildMember');
        expect(result2.actions[0].payload['key'], 'money');
        expect(result2.actions[0].payload['value'], '100');
        expect(result2.actions[0].payload['contextId'], '67890:((author.id))');
      });

      test('setGuildMemberVar compiles to scope guildMember', () {
        final compiler = BdfdCompiler();
        final result = compiler.compile(r'$setGuildMemberVar[money;100;12345;67890]');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        expect(result.actions[0].type, BotCreatorActionType.setScopedVariable);
        expect(result.actions[0].payload['scope'], 'guildMember');
        expect(result.actions[0].payload['key'], 'money');
        expect(result.actions[0].payload['value'], '100');
        expect(result.actions[0].payload['contextId'], '67890:12345');
      });

      test('resetUserVar with 3 arguments compiles to scope guildMember', () {
        final compiler = BdfdCompiler();
        final result = compiler.compile(r'$resetUserVar[money;12345;67890]');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        expect(result.actions[0].type, BotCreatorActionType.removeScopedVariable);
        expect(result.actions[0].payload['scope'], 'guildMember');
        expect(result.actions[0].payload['key'], 'money');
        expect(result.actions[0].payload['contextId'], '67890:12345');
      });
    });
  });
}
