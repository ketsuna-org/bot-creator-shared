import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdCompiler', () {
    test('compiles runtime variable placeholders and scoped vars', () {
      final result = BdfdCompiler().compile(
        r'Hello $username$setUserVar[lastAuthor;$authorID]$getUserVar[lastAuthor]',
      );

      expect(result.hasErrors, isFalse);
      // Single response: setUserVar no longer flushes, so the text content from
      // before and after the variable set is merged into one respondWithMessage.
      expect(result.actions, hasLength(2));
      expect(result.actions.first.type, BotCreatorActionType.setScopedVariable);
      expect(result.actions.first.payload['scope'], 'user');
      expect(result.actions.first.payload['key'], 'lastAuthor');
      expect(result.actions.first.payload['value'], '((author.id))');
      expect(result.actions.last.type, BotCreatorActionType.respondWithMessage);
      expect(
        result.actions.last.payload['content'],
        'Hello ((user.username))((user.bc_lastAuthor))',
      );
    });

    test('compiles message[] helper for normal/slash fallback', () {
      final result = BdfdCompiler().compile(
        r'$reply$message[1;text]|$message[text]|$message[>]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(
        result.actions.single.payload['content'],
        '((message.content[0]|opts.text))|((opts.text))|((last(split(message.content, " "))))',
      );
    });

    test('compiles message helper without brackets', () {
      final result = BdfdCompiler().compile(r'$reply$message');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(result.actions.single.payload['content'], '((message.content))');
    });

    test('compiles args helper with runtime args fallback', () {
      final result = BdfdCompiler().compile(r'$reply$args[2]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(
        result.actions.single.payload['content'],
        '((message.content[1]|args.2))',
      );
    });

    test('compiles getTimestampMs as runtime placeholder', () {
      final result = BdfdCompiler().compile(r'$reply$getTimestampMs');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));

      final raw = result.actions.single.payload['content']?.toString() ?? '';
      expect(raw, '((getTimestampMs))');

      // Verify it resolves to a current-ish timestamp at runtime.
      final resolved = resolveTemplatePlaceholders(raw, <String, String>{});
      final value = int.tryParse(resolved);
      expect(value, isNotNull);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      expect(value! >= now - 1000, isTrue);
      expect(value <= now + 1000, isTrue);
    });

    test(
      'resolves sub with getTimestampMs and messageTimestamp at runtime',
      () {
        final result = BdfdCompiler().compile(
          r'$reply$c[]Latency: $sub[$getTimestampMs;$messageTimestamp] ms',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));

        final compiled =
            result.actions.single.payload['content']?.toString() ?? '';
        final messageTimestamp =
            DateTime.now().toUtc().millisecondsSinceEpoch - 25;
        final resolved = resolveTemplatePlaceholders(compiled, <String, String>{
          'message.timestamp': messageTimestamp.toString(),
        });

        final match = RegExp(r'^Latency: (\d+) ms$').firstMatch(resolved);
        expect(match, isNotNull);
        expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(0));
      },
    );

    test('resolves ping compiled to bot.ping at runtime', () {
      final result = BdfdCompiler().compile(r'$reply$c[]Ping: $ping ms');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));

      final compiled =
          result.actions.single.payload['content']?.toString() ?? '';
      // Verify the compiled output contains bot.ping reference
      expect(compiled, contains('bot.ping'));

      final resolved = resolveTemplatePlaceholders(compiled, <String, String>{
        'bot.ping': '52',
      });

      expect(resolved, 'Ping: 52 ms');
    });

    test('compiles channelSendMessage helper', () {
      final result = BdfdCompiler().compile(
        r'$channelSendMessage[123456789012345678;Hello!]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['channelId'], '123456789012345678');
      expect(result.actions.single.payload['content'], 'Hello!');
    });

    test('compiles mentionedChannels helper', () {
      final result = BdfdCompiler().compile(
        r'$reply$mentionedChannels[1]|$mentionedChannels[1;yes]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(
        result.actions.single.payload['content'],
        '((message.mentions[0]))|((message.mentions[0]|channel.id))',
      );
    });

    test('compiles user identity helper functions without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$reply$authorAvatar|$authorID|$authorOfMessage|$creationDate|$discriminator|$displayName|$displayName[123]|$getUserStatus|$getCustomStatus|$isAdmin|$isBooster|$isBot|$isUserDMEnabled|$nickname|$nickname[123]|$userAvatar|$userBadges|$userBanner|$userBannerColor|$userExists|$userID|$userInfo|$userJoined|$userJoinedDiscord|$username|$username[123]|$userPerms|$userServerAvatar|$findUser',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final content =
          result.actions.single.payload['content']?.toString() ?? '';
      expect(content, contains('((author.avatar))'));
      expect(content, contains('((author.id))'));
      expect(content, contains('((userperms[;-1;, ]))'));
      expect(content, contains('((user.id))'));
    });

    test('compiles changeUsername and changeUsernameWithID helpers', () {
      final result = BdfdCompiler().compile(
        r'$changeUsername[NewName]'
        r'$changeUsernameWithID[1234567890;AnotherName]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.updateSelfUser);
      expect(result.actions[0].payload['username'], 'NewName');
      expect(result.actions[1].type, BotCreatorActionType.ifBlock);
    });

    test('surfaces unsupported functions as compile errors', () {
      final result = BdfdCompiler().compile(r'$totallyFakeFunction[$authorID]');

      expect(result.hasErrors, isTrue);
      expect(result.actions, isEmpty);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$totallyFakeFunction');
      expect(
        result.diagnostics.single.stage,
        BdfdCompileDiagnosticStage.transpiler,
      );
    });

    test('treats unresolved no-arg dollar token as literal text', () {
      final result = BdfdCompiler().compile(r'$reply$test');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(result.actions.single.payload['content'], r'$test');
    });

    test('preserves nested unsupported text functions as warnings only', () {
      final result = BdfdCompiler().compile(
        r'$description[Hello $unknownFunction[test]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(
        result.diagnostics.single.severity,
        BdfdCompileDiagnosticSeverity.warning,
      );
    });

    test('compiles addEmoji function (standalone & inline/nested)', () {
      final result = BdfdCompiler().compile(
        r'Added emoji: $addEmoji[myEmoji;https://example.com/image.png;yes]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));

      expect(result.actions[0].type, BotCreatorActionType.createEmoji);
      expect(result.actions[0].key, startsWith('_bdfd_createemoji_'));
      expect(result.actions[0].payload['name'], 'myEmoji');
      expect(
        result.actions[0].payload['imageUrl'],
        'https://example.com/image.png',
      );

      expect(result.actions[1].type, BotCreatorActionType.respondWithMessage);
      final content = result.actions[1].payload['content'] as String;
      expect(content, startsWith('Added emoji: (('));
      expect(content, endsWith('))'));

      // Test template resolution of the created emoji placeholder
      final key = result.actions[0].key!;
      final resolvedStatic = resolveTemplatePlaceholders(content, {
        '$key.emojiId': '9876543210',
        '$key.name': 'myEmoji',
        '$key.animated': 'false',
      });
      expect(resolvedStatic, 'Added emoji: <:myEmoji:9876543210>');

      final resolvedAnimated = resolveTemplatePlaceholders(content, {
        '$key.emojiId': '9876543210',
        '$key.name': 'myEmoji',
        '$key.animated': 'true',
      });
      expect(resolvedAnimated, 'Added emoji: <a:myEmoji:9876543210>');
    });
  });
}
